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

import CoreGraphics

import Darwin

import Foundation

import os

/// A complete image of the guest display.
///
/// - Important: The wrapper is `@unchecked Sendable` because the image it carries is immutable and was
///   built from a private copy of the pixels; nothing else holds a reference to that storage.
struct RFBFrame: @unchecked Sendable {

    /// The pixels of the display, one point per guest pixel.
    let image: CGImage
}

/// The pointer image the guest has defined.
///
/// - Important: The wrapper is `@unchecked Sendable` for the same reason as `RFBFrame`.
struct RFBCursor: @unchecked Sendable {

    /// The pointer image, or `nil` if the guest hides its pointer.
    let image: CGImage?

    /// The point of the image that marks the pointer position, in guest pixels from the top-left corner.
    let hotspot: CGPoint
}

/// The reasons a display connection can fail.
enum RFBError: Error, CustomStringConvertible {

    /// The server sent something the protocol does not allow.
    case protocolViolation(String)

    /// The server declined the connection and gave a reason.
    case refused(String)

    /// The server offered no security type this client implements.
    case unsupportedSecurity

    /// The server used an encoding this client never advertised.
    case unsupportedEncoding(Int32)

    /// A short, technical description of the failure.
    var description: String {
        switch self {
        case .protocolViolation(let detail): "protocol violation: \(detail)"
        case .refused(let reason): "connection refused: \(reason)"
        case .unsupportedSecurity: "no supported security type"
        case .unsupportedEncoding(let encoding): "unexpected encoding \(encoding)"
        }
    }
}

/// A client for the remote framebuffer protocol (RFB 3.8) spoken by the emulator's display server.
///
/// The connection runs over a socket that is handed to the emulator as an already connected descriptor,
/// so there is no address, no port and no authentication: the server treats it as a trusted client.
///
/// ## Threads
/// A dedicated thread performs the blocking reads: first the handshake, then the message loop. That
/// thread exclusively owns the framebuffer and everything else it parses. After each complete update
/// it builds an immutable image from a copy of the framebuffer and reports it through the event
/// handler, still on the reading thread.
///
/// Input is sent from whichever thread calls the senders. Messages are written on a private serial
/// queue, which keeps them in order and keeps a slow emulator from blocking the caller.
///
/// ## Pacing
/// The client asks for one incremental update of the whole display after each update it has received.
/// The server answers as soon as something changed, so the update rate follows the guest without any
/// timer.
///
/// - Important: The type is `@unchecked Sendable`. The state parsed by the reading thread is never
///   touched by any other thread, the state shared with the senders is behind a lock, and the socket
///   is itself safe to use from several threads.
final class RFBConnection: @unchecked Sendable {

    /// What the connection reports to its owner.
    enum Event: Sendable {

        /// The display has new content, or a new size.
        case frame(RFBFrame)

        /// The guest has defined a new pointer image.
        case cursor(RFBCursor)

        /// The connection ended. Carries the failure, or `nil` if it ended because it was asked to or
        /// because the emulator went away.
        case closed((any Error)?)
    }

    /// The encodings this client understands.
    private enum Encoding {
        static let raw: Int32 = 0
        static let desktopSize: Int32 = -223
        static let extendedDesktopSize: Int32 = -308
        static let extendedKeyEvent: Int32 = -258
        static let alphaCursor: Int32 = -314

        /// The order of the list is the order of preference sent to the server.
        static let advertised: [Int32] = [raw, desktopSize, extendedDesktopSize, extendedKeyEvent, alphaCursor]
    }

    /// The state the reading thread shares with the senders.
    private struct SharedState: Sendable {
        var isStarted = false
        var isReady = false
        var isClosing = false
        var supportsExtendedKeyEvents = false
        var width = 0
        var height = 0
    }

    /// The largest display dimension accepted from the server, in pixels.
    private static let maximumDimension = 16384

    /// The longest string accepted from the server, in bytes.
    private static let maximumTextLength = 1 << 20

    /// Reads at least this large bypass the internal buffer and land directly in their destination.
    private static let directReadThreshold = 4096

    /// How much a buffered read asks the socket for at once.
    private static let bufferedReadSize = 16384

    /// The size of the socket buffers of a display connection. Large enough to hold a sizeable part of
    /// a full-screen update, so that the server does not have to wait for the reader at every row.
    static let socketBufferSize: Int32 = 1 << 20

    /// The connection to the emulator's display server.
    private let socket: UnixSocket

    /// Receives frames, pointer images and the end of the connection, on the reading thread.
    private let handler: @Sendable (Event) -> Void

    /// The state shared between the reading thread and the senders.
    private let shared = OSAllocatedUnfairLock(initialState: SharedState())

    /// Orders and performs the writes issued by the senders.
    private let outputQueue = DispatchQueue(label: "RFBConnection.output", qos: .userInteractive)

    // MARK: Reading Thread State

    /// Bytes received but not consumed yet. Owned by the reading thread.
    private var pending = Data()

    /// The pixels of the display, four bytes each, rows top to bottom. Owned by the reading thread.
    private var framebuffer = Data()

    /// The width of the framebuffer, in pixels. Owned by the reading thread.
    private var width = 0

    /// The height of the framebuffer, in pixels. Owned by the reading thread.
    private var height = 0

    // MARK: - Lifecycle

    /// Starts the reading thread, which performs the handshake and then receives updates.
    ///
    /// Calling it more than once has no effect.
    func start() {

        let isFirstStart = shared.withLock { state -> Bool in
            guard !state.isStarted else { return false }
            state.isStarted = true
            return true
        }

        guard isFirstStart else { return }

        let thread = Thread { [self] in self.run() }
        thread.name = "RFBConnection"
        thread.qualityOfService = .userInteractive
        thread.start()
    }

    /// Ends the connection. The reading thread reports `.closed(nil)` once it has noticed.
    func close() {
        shared.withLock { $0.isClosing = true }
        socket.shutdown()
    }

    /// The body of the reading thread.
    private func run() {

        var failure: (any Error)?

        do {
            try performHandshake()
            try configureSession()

            while true { try receiveMessage() }

        } catch {
            failure = error
        }

        let wasRequested = shared.withLock { state -> Bool in
            state.isReady = false
            return state.isClosing
        }

        socket.shutdown()

        // The end of the stream is how the connection ends when the emulator exits; it is not a failure
        // of the display. Everything else is reported, unless the connection was being closed anyway.
        if wasRequested || Self.isEndOfStream(failure) {
            handler(.closed(nil))
        } else {
            handler(.closed(failure))
        }
    }

    // MARK: - Handshake

    /// Agrees on the protocol version and on the absence of authentication, and reads the server's
    /// description of the display.
    private func performHandshake() throws {

        let version = try read(12)

        guard version.starts(with: Array("RFB ".utf8)) else {
            throw RFBError.protocolViolation("unexpected protocol version")
        }

        try socket.write(Data("RFB 003.008\n".utf8))

        let typeCount = Int(try readUInt8())

        guard typeCount > 0 else { throw RFBError.refused(try readReason()) }

        let types = try read(typeCount)

        guard types.contains(1) else { throw RFBError.unsupportedSecurity }

        // Security type 1: none.
        try socket.write(Data([1]))

        guard try readUInt32() == 0 else { throw RFBError.refused(try readReason()) }

        // ClientInit with the shared flag set: other views of the same machine may be connected too.
        try socket.write(Data([1]))

        // ServerInit: size, the server's pixel format (ignored, replaced below) and the desktop name.
        let serverWidth = try readUInt16()
        let serverHeight = try readUInt16()
        _ = try read(16)

        let nameLength = Int(try readUInt32())

        guard nameLength <= Self.maximumTextLength else {
            throw RFBError.protocolViolation("desktop name too long")
        }

        _ = try read(nameLength)

        try resize(width: serverWidth, height: serverHeight)
    }

    /// Selects the pixel format and the encodings, and asks for the first, complete, update.
    ///
    /// The pixel format is 32 bits per pixel, little-endian, with red, green and blue in bits 16, 8
    /// and 0. It is the server's native format, so the server sends its surface without converting it,
    /// and in memory every pixel is laid out as blue, green, red and an unused byte.
    private func configureSession() throws {

        var message = Data()

        // SetPixelFormat.
        message.append(contentsOf: [0, 0, 0, 0])
        message.append(contentsOf: [32, 24, 0, 1])
        message.appendBigEndian(UInt16(255))
        message.appendBigEndian(UInt16(255))
        message.appendBigEndian(UInt16(255))
        message.append(contentsOf: [16, 8, 0, 0, 0, 0])

        // SetEncodings.
        message.append(contentsOf: [2, 0])
        message.appendBigEndian(UInt16(Encoding.advertised.count))

        for encoding in Encoding.advertised {
            message.appendBigEndian(UInt32(bitPattern: encoding))
        }

        message.append(updateRequest(incremental: false))

        try socket.write(message)

        let (width, height) = (self.width, self.height)

        shared.withLock { state in
            state.isReady = true
            state.width = width
            state.height = height
        }
    }

    // MARK: - Messages

    /// Receives and handles one message from the server.
    private func receiveMessage() throws {

        let type = try readUInt8()

        switch type {
        case 0:
            try receiveFramebufferUpdate()

        case 1:
            // SetColourMapEntries: irrelevant in true-colour mode, skipped.
            _ = try read(3)
            let count = try readUInt16()
            try skip(count * 6)

        case 2:
            // Bell.
            break

        case 3:
            // ServerCutText: the clipboard is not shared, skipped.
            _ = try read(3)
            try skip(Int(try readUInt32()))

        default:
            throw RFBError.protocolViolation("unexpected message type \(type)")
        }
    }

    /// Receives the rectangles of one update, applies them and reports the outcome.
    private func receiveFramebufferUpdate() throws {

        _ = try read(1)
        let count = try readUInt16()

        var hasNewContent = false
        var cursor: RFBCursor?

        for _ in 0..<count {

            let x = try readUInt16()
            let y = try readUInt16()
            let rectangleWidth = try readUInt16()
            let rectangleHeight = try readUInt16()
            let encoding = Int32(bitPattern: try readUInt32())

            guard rectangleWidth <= Self.maximumDimension, rectangleHeight <= Self.maximumDimension else {
                throw RFBError.protocolViolation("rectangle too large")
            }

            switch encoding {
            case Encoding.raw:
                let pixels = try read(rectangleWidth * rectangleHeight * 4)

                if blit(pixels, x: x, y: y, width: rectangleWidth, height: rectangleHeight) {
                    hasNewContent = true
                }

            case Encoding.desktopSize:
                try resize(width: rectangleWidth, height: rectangleHeight)
                hasNewContent = true

            case Encoding.extendedDesktopSize:
                let screenCount = Int(try readUInt8())
                _ = try read(3)
                _ = try read(16 * screenCount)

                // `x == 1` marks the answer to a size request of this client, `y` being its status.
                // The emulator answers 4, "forwarded to the guest", when it passes the request on
                // (the guest's own resize, if any, follows as a separate update), and 3 when the
                // guest's graphics device cannot change its size at all.
                if x == 1 && y != 0 && y != 4 {
                    VZKitLogger.default.info("The guest display declined a size change (status \(y))")
                }

                if rectangleWidth != width || rectangleHeight != height {
                    try resize(width: rectangleWidth, height: rectangleHeight)
                    hasNewContent = true
                }

            case Encoding.extendedKeyEvent:
                shared.withLock { $0.supportsExtendedKeyEvents = true }

            case Encoding.alphaCursor:
                // The encoding of the pointer pixels, always raw, followed by the pixels themselves.
                _ = try read(4)
                let pixels = try read(rectangleWidth * rectangleHeight * 4)

                cursor = Self.makeCursor(
                    pixels,
                    width: rectangleWidth,
                    height: rectangleHeight,
                    hotspot: CGPoint(x: x, y: y)
                )

            default:
                throw RFBError.unsupportedEncoding(encoding)
            }
        }

        // Asking for the next update first lets the server prepare it while this one is delivered.
        try socket.write(updateRequest(incremental: true))

        if let cursor { handler(.cursor(cursor)) }

        if hasNewContent, let frame = makeFrame() { handler(.frame(frame)) }
    }

    /// A FramebufferUpdateRequest covering the whole display.
    private func updateRequest(incremental: Bool) -> Data {
        var message = Data([3, incremental ? 1 : 0])
        message.appendBigEndian(UInt16(0))
        message.appendBigEndian(UInt16(0))
        message.appendBigEndian(UInt16(clamping: width))
        message.appendBigEndian(UInt16(clamping: height))
        return message
    }

    // MARK: - Framebuffer

    /// Gives the framebuffer a new size. Its content is cleared; the server sends it again.
    private func resize(width newWidth: Int, height newHeight: Int) throws {

        guard newWidth <= Self.maximumDimension, newHeight <= Self.maximumDimension else {
            throw RFBError.protocolViolation("display too large")
        }

        width = newWidth
        height = newHeight
        framebuffer = Data(count: newWidth * newHeight * 4)

        shared.withLock { state in
            state.width = newWidth
            state.height = newHeight
        }
    }

    /// Copies a rectangle of raw pixels into the framebuffer, row by row.
    ///
    /// - Returns: Whether the rectangle was applied. One that does not fit is discarded.
    private func blit(_ pixels: Data, x: Int, y: Int, width rectangleWidth: Int, height rectangleHeight: Int) -> Bool {

        guard rectangleWidth > 0, rectangleHeight > 0,
              x + rectangleWidth <= width, y + rectangleHeight <= height,
              pixels.count == rectangleWidth * rectangleHeight * 4 else { return false }

        let rowLength = rectangleWidth * 4
        let stride = width * 4
        let base = pixels.startIndex

        for row in 0..<rectangleHeight {
            let source = base + row * rowLength
            let destination = (y + row) * stride + x * 4

            framebuffer.replaceSubrange(
                destination..<(destination + rowLength),
                with: pixels[source..<(source + rowLength)]
            )
        }

        return true
    }

    /// Builds an immutable image from a private copy of the framebuffer.
    ///
    /// The copy is what makes the image safe to hand to another thread: the framebuffer keeps changing,
    /// and is replaced altogether when the display is resized.
    private func makeFrame() -> RFBFrame? {

        guard width > 0, height > 0 else { return nil }

        let copy: CFData? = unsafe framebuffer.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> CFData? in
            guard let base = raw.baseAddress else { return nil }
            return unsafe CFDataCreate(kCFAllocatorDefault, base.assumingMemoryBound(to: UInt8.self), raw.count)
        }

        guard let copy, let provider = CGDataProvider(data: copy) else { return nil }

        let bitmapInfo = CGBitmapInfo(
            rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.noneSkipFirst.rawValue
        )

        guard let image = unsafe CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else { return nil }

        return RFBFrame(image: image)
    }

    /// Builds the pointer image from the pixels of an alpha cursor update.
    ///
    /// The server sends blue, green, red and a straight (not premultiplied) alpha value per pixel. The
    /// pixels are premultiplied here, which is the alpha representation every drawing path supports.
    private static func makeCursor(_ pixels: Data, width: Int, height: Int, hotspot: CGPoint) -> RFBCursor {

        guard width > 0, height > 0, pixels.count == width * height * 4 else {
            return RFBCursor(image: nil, hotspot: .zero)
        }

        var bytes = [UInt8](pixels)

        for offset in Swift.stride(from: 0, to: bytes.count, by: 4) {
            let alpha = UInt32(bytes[offset + 3])

            for channel in offset..<(offset + 3) {
                bytes[channel] = UInt8((UInt32(bytes[channel]) * alpha + 127) / 255)
            }
        }

        let bitmapInfo = CGBitmapInfo(
            rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        )

        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let image = unsafe CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: bitmapInfo,
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) else { return RFBCursor(image: nil, hotspot: .zero) }

        return RFBCursor(image: image, hotspot: hotspot)
    }

    // MARK: - Input

    /// Reports the pointer position and the state of the buttons.
    ///
    /// - Parameters:
    ///   - buttons: The buttons held down: 1 left, 2 middle, 4 right, 8 wheel up, 16 wheel down.
    ///   - x: The horizontal position, in framebuffer pixels from the left edge.
    ///   - y: The vertical position, in framebuffer pixels from the top edge.
    func sendPointer(buttons: UInt8, x: Int, y: Int) {

        guard let size = readySize else { return }

        var message = Data([5, buttons])
        message.appendBigEndian(UInt16(clamping: min(max(x, 0), max(size.width - 1, 0))))
        message.appendBigEndian(UInt16(clamping: min(max(y, 0), max(size.height - 1, 0))))

        enqueue(message)
    }

    /// Reports a key being pressed or released.
    ///
    /// The key is identified by its position on the keyboard, not by the character it produces, so the
    /// guest applies its own keyboard layout. The symbol is used by the server only to keep the lock
    /// keys of guest and host in step.
    ///
    /// - Parameters:
    ///   - scancode: The XT set 1 scancode, with `0x80` added for keys sent with an `E0` prefix.
    ///   - keysym: The letter produced on the host for letter keys, otherwise `0`.
    ///   - isDown: Whether the key goes down or up.
    func sendKey(scancode: UInt16, keysym: UInt32, isDown: Bool) {

        let state = shared.withLock { ($0.isReady, $0.supportsExtendedKeyEvents) }

        guard state.0 else { return }

        var message: Data

        if state.1 {
            message = Data([255, 0])
            message.appendBigEndian(UInt16(isDown ? 1 : 0))
            message.appendBigEndian(keysym)
            message.appendBigEndian(UInt32(scancode))

        } else if keysym != 0 {
            // Without the extension only symbols can be sent, and only letters carry one.
            message = Data([4, isDown ? 1 : 0, 0, 0])
            message.appendBigEndian(keysym)

        } else {
            return
        }

        enqueue(message)
    }

    /// Asks the guest to change the resolution of its display.
    ///
    /// The server forwards the request to the guest's graphics device. If the guest complies, a new
    /// frame of the requested size follows.
    ///
    /// - Returns: Whether the request was sent; `false` while the connection is not established.
    @discardableResult
    func sendDesktopSize(width: Int, height: Int) -> Bool {

        guard readySize != nil else { return false }

        let width = UInt16(clamping: width)
        let height = UInt16(clamping: height)

        var message = Data([251, 0])
        message.appendBigEndian(width)
        message.appendBigEndian(height)
        message.append(contentsOf: [1, 0])

        // The one screen: identifier, position, size, flags.
        message.appendBigEndian(UInt32(0))
        message.appendBigEndian(UInt16(0))
        message.appendBigEndian(UInt16(0))
        message.appendBigEndian(width)
        message.appendBigEndian(height)
        message.appendBigEndian(UInt32(0))

        enqueue(message)
        return true
    }

    /// The size of the display, once the connection is established.
    private var readySize: (width: Int, height: Int)? {
        shared.withLock { state in
            state.isReady ? (state.width, state.height) : nil
        }
    }

    /// Writes a message on the output queue. A failure means the connection is ending, which the
    /// reading thread reports.
    private func enqueue(_ message: Data) {
        outputQueue.async { [socket] in
            try? socket.write(message)
        }
    }

    // MARK: - Reading

    /// Reads an exact number of bytes.
    ///
    /// Small reads are served from an internal buffer, so that parsing a header does not cost a system
    /// call per field; large ones (pixel data) are read straight into a buffer of their own.
    ///
    /// - Returns: A buffer that starts at index zero.
    private func read(_ count: Int) throws -> Data {

        guard count > 0 else { return Data() }

        if pending.count < count && count - pending.count >= Self.directReadThreshold {
            var result = Data(pending)
            pending = Data()

            result.append(try socket.readExactly(count - result.count))
            return result
        }

        while pending.count < count {
            pending.append(try socket.read(upTo: Self.bufferedReadSize))
        }

        let result = Data(pending.prefix(count))
        pending = Data(pending.dropFirst(count))
        return result
    }

    /// Discards a number of bytes without holding all of them in memory at once.
    private func skip(_ count: Int) throws {

        var remaining = count

        while remaining > 0 {
            let chunk = min(remaining, 65536)
            _ = try read(chunk)
            remaining -= chunk
        }
    }

    /// Reads one byte.
    private func readUInt8() throws -> UInt8 {
        let bytes = try read(1)
        return bytes[bytes.startIndex]
    }

    /// Reads a big-endian 16-bit unsigned integer.
    private func readUInt16() throws -> Int {
        let bytes = try read(2)
        let start = bytes.startIndex
        return Int(bytes[start]) << 8 | Int(bytes[start + 1])
    }

    /// Reads a big-endian 32-bit unsigned integer.
    private func readUInt32() throws -> UInt32 {
        let bytes = try read(4)
        let start = bytes.startIndex
        return UInt32(bytes[start]) << 24 | UInt32(bytes[start + 1]) << 16
            | UInt32(bytes[start + 2]) << 8 | UInt32(bytes[start + 3])
    }

    /// Reads the length-prefixed reason string of a refusal.
    private func readReason() throws -> String {

        let length = Int(try readUInt32())

        guard length <= Self.maximumTextLength else {
            throw RFBError.protocolViolation("reason too long")
        }

        return String(decoding: try read(length), as: UTF8.self)
    }

    /// Whether an error only means that the stream has ended.
    private static func isEndOfStream(_ error: (any Error)?) -> Bool {
        guard let error = error as? UnixSocketError, case .closed = error else { return false }
        return true
    }

    // MARK: - Initializers

    /// Creates a client on top of a connected socket. Nothing happens until `start()` is called.
    ///
    /// - Parameters:
    ///   - socket: The client end of a connection to the emulator's display server.
    ///   - handler: Receives the events of the connection, on its reading thread.
    init(socket: UnixSocket, handler: @escaping @Sendable (Event) -> Void) {
        self.socket = socket
        self.handler = handler
    }
}

extension UnixSocket {

    /// Creates a connected pair of sockets suited to carry a display connection.
    ///
    /// Both ends get larger buffers than the default, which is small enough to make the server stop at
    /// every few rows of a full-screen update.
    ///
    /// - Returns: The local end and the raw descriptor of the peer end, which the caller owns.
    /// - Throws: `UnixSocketError.system` if the pair cannot be created.
    static func makeDisplayPair() throws -> (local: UnixSocket, peer: Int32) {

        let pair = try makePair()
        var size = RFBConnection.socketBufferSize
        let length = socklen_t(MemoryLayout<Int32>.size)

        // Failures only cost throughput.
        _ = unsafe setsockopt(pair.local.descriptor, SOL_SOCKET, SO_RCVBUF, &size, length)
        _ = unsafe setsockopt(pair.local.descriptor, SOL_SOCKET, SO_SNDBUF, &size, length)
        _ = unsafe setsockopt(pair.peer, SOL_SOCKET, SO_RCVBUF, &size, length)
        _ = unsafe setsockopt(pair.peer, SOL_SOCKET, SO_SNDBUF, &size, length)

        // The peer is going to live in the emulator; this process must not die of a write to it either.
        var enabled: Int32 = 1
        _ = unsafe setsockopt(pair.peer, SOL_SOCKET, SO_NOSIGPIPE, &enabled, length)

        return pair
    }
}

private extension Data {

    /// Appends a 16-bit value in network byte order.
    mutating func appendBigEndian(_ value: UInt16) {
        append(UInt8(truncatingIfNeeded: value >> 8))
        append(UInt8(truncatingIfNeeded: value))
    }

    /// Appends a 32-bit value in network byte order.
    mutating func appendBigEndian(_ value: UInt32) {
        append(UInt8(truncatingIfNeeded: value >> 24))
        append(UInt8(truncatingIfNeeded: value >> 16))
        append(UInt8(truncatingIfNeeded: value >> 8))
        append(UInt8(truncatingIfNeeded: value))
    }
}
