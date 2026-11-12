//
//  Copyright 2026 Giuseppe Rocco
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Darwin

import Foundation

/// The reasons a socket operation can fail.
enum UnixSocketError: Error {

    /// The peer closed the connection, or the socket was shut down locally.
    case closed

    /// A system call failed with the given `errno` value.
    case system(Int32)
}

/// An owned, connected stream socket in the UNIX domain.
///
/// This is the only transport the backend uses to talk to an emulator: one socket carries the control
/// protocol, another the display protocol. Sockets are never bound to a path. They are created as
/// connected pairs and one end is handed to the emulator as an open descriptor, which keeps them out
/// of the file system and out of reach of the path length limit of socket addresses.
///
/// Reads block and are meant to be issued from a dedicated thread. Writes are serialized by a lock
/// and may come from any thread. `shutdown()` unblocks a pending read from the outside.
///
/// - Important: The type is `@unchecked Sendable` because the descriptor is immutable and every
///   operation on it is a thread-safe system call; the write path adds its own lock so that
///   messages are never interleaved.
final class UnixSocket: @unchecked Sendable {

    /// The underlying descriptor. Closed when the last reference to the socket goes away.
    let descriptor: Int32

    /// Serializes writers so that a message is never interleaved with another one.
    private let writeLock = NSLock()

    // MARK: - Reading

    /// Reads whatever is available, blocking until at least one byte arrives.
    ///
    /// - Parameter count: The most bytes to return.
    /// - Returns: Between one and `count` bytes.
    /// - Throws: `UnixSocketError.closed` at end of stream, `UnixSocketError.system` on failure.
    func read(upTo count: Int) throws -> Data {

        var buffer = [UInt8](repeating: 0, count: max(count, 1))

        while true {
            let (received, code) = buffer.withUnsafeMutableBytes { (raw: UnsafeMutableRawBufferPointer) -> (Int, Int32) in
                let result = unsafe Darwin.read(descriptor, raw.baseAddress, raw.count)
                return (result, errno)
            }

            if received > 0 { return Data(buffer[0..<received]) }
            if received == 0 { throw UnixSocketError.closed }
            if code == EINTR || code == EAGAIN { continue }

            throw UnixSocketError.system(code)
        }
    }

    /// Reads an exact number of bytes, blocking until all of them have arrived.
    ///
    /// - Parameter count: The number of bytes to read.
    /// - Returns: Exactly `count` bytes.
    /// - Throws: `UnixSocketError.closed` if the stream ends first, `UnixSocketError.system` on failure.
    func readExactly(_ count: Int) throws -> Data {

        guard count > 0 else { return Data() }

        var buffer = Data(count: count)
        var offset = 0

        while offset < count {
            let (received, code) = unsafe buffer.withUnsafeMutableBytes { (raw: UnsafeMutableRawBufferPointer) -> (Int, Int32) in
                guard let base = raw.baseAddress else { return (-1, EFAULT) }
                let result = unsafe Darwin.read(descriptor, base + offset, count - offset)
                return (result, errno)
            }

            if received > 0 { offset += received; continue }
            if received == 0 { throw UnixSocketError.closed }
            if code == EINTR || code == EAGAIN { continue }

            throw UnixSocketError.system(code)
        }

        return buffer
    }

    // MARK: - Writing

    /// Writes a whole message, optionally passing an open descriptor along with its first byte.
    ///
    /// Passing a descriptor is how files and sockets are handed to a running emulator: the receiver
    /// obtains its own duplicate, and the caller remains the owner of the original.
    ///
    /// - Parameters:
    ///   - data: The bytes to send.
    ///   - passedDescriptor: A descriptor to transfer as ancillary data, if any.
    /// - Throws: `UnixSocketError.closed` if the peer is gone, `UnixSocketError.system` on failure.
    func write(_ data: Data, passing passedDescriptor: Int32? = nil) throws {

        guard !data.isEmpty else { return }

        writeLock.lock()
        defer { writeLock.unlock() }

        var offset = 0
        var pendingDescriptor = passedDescriptor

        while offset < data.count {
            let (sent, code) = unsafe data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> (Int, Int32) in
                guard let base = raw.baseAddress else { return (-1, EFAULT) }
                let result = unsafe Self.send(
                    on: descriptor,
                    bytes: base + offset,
                    count: raw.count - offset,
                    passing: pendingDescriptor
                )
                return (result, errno)
            }

            if sent > 0 {
                offset += sent
                pendingDescriptor = nil
                continue
            }

            if sent < 0 && (code == EINTR || code == EAGAIN) { continue }
            if sent < 0 && (code == EPIPE || code == ECONNRESET) { throw UnixSocketError.closed }

            throw UnixSocketError.system(sent < 0 ? code : EIO)
        }
    }

    /// Issues one `sendmsg` call, attaching a descriptor as `SCM_RIGHTS` ancillary data when asked to.
    ///
    /// The control message is laid out by hand. On this platform its header is three 32-bit fields
    /// (length, level, type) followed directly by the payload, so a message carrying a single
    /// descriptor is exactly four 32-bit words with a total length of sixteen bytes.
    private static func send(
        on socket: Int32,
        bytes: UnsafeRawPointer,
        count: Int,
        passing passedDescriptor: Int32?
    ) -> Int {

        var vector = unsafe iovec(iov_base: UnsafeMutableRawPointer(mutating: bytes), iov_len: count)

        return withUnsafeMutablePointer(to: &vector) { (vectorPointer: UnsafeMutablePointer<iovec>) -> Int in

            var message = unsafe msghdr()
            unsafe message.msg_iov = vectorPointer
            unsafe message.msg_iovlen = 1

            guard let passedDescriptor else {
                return unsafe sendmsg(socket, &message, 0)
            }

            var control: [Int32] = [16, SOL_SOCKET, SCM_RIGHTS, passedDescriptor]

            return control.withUnsafeMutableBytes { (controlBuffer: UnsafeMutableRawBufferPointer) -> Int in
                unsafe message.msg_control = controlBuffer.baseAddress
                unsafe message.msg_controllen = socklen_t(controlBuffer.count)

                return unsafe sendmsg(socket, &message, 0)
            }
        }
    }

    // MARK: - Lifecycle

    /// Disables both directions of the connection.
    ///
    /// A thread blocked in a read wakes up with an end-of-stream condition, and the peer observes the
    /// connection as closed. The descriptor itself stays valid until the socket is released, so a
    /// concurrent reader never operates on a recycled descriptor number.
    func shutdown() {
        _ = Darwin.shutdown(descriptor, SHUT_RDWR)
    }

    /// Takes ownership of a connected socket.
    ///
    /// The socket is configured not to raise `SIGPIPE` when the peer disappears (the default action of
    /// that signal terminates the whole application) and not to leak into child processes.
    ///
    /// - Parameter descriptor: A connected stream socket. It is closed when this object is released.
    init(adopting descriptor: Int32) {
        self.descriptor = descriptor

        var enabled: Int32 = 1
        _ = unsafe setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &enabled, socklen_t(MemoryLayout<Int32>.size))
        _ = fcntl(descriptor, F_SETFD, FD_CLOEXEC)
    }

    deinit {
        _ = Darwin.close(descriptor)
    }

    /// Creates a connected pair of sockets.
    ///
    /// - Returns: The local end, owned by a `UnixSocket`, and the raw descriptor of the peer end, which
    ///   the caller owns and is expected to pass on and then close.
    /// - Throws: `UnixSocketError.system` if the pair cannot be created.
    static func makePair() throws -> (local: UnixSocket, peer: Int32) {

        var descriptors: [Int32] = [-1, -1]

        guard unsafe socketpair(AF_UNIX, SOCK_STREAM, 0, &descriptors) == 0 else {
            throw UnixSocketError.system(errno)
        }

        _ = fcntl(descriptors[1], F_SETFD, FD_CLOEXEC)

        return (UnixSocket(adopting: descriptors[0]), descriptors[1])
    }
}
