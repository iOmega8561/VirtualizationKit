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

import Foundation

/// A client for the emulator's machine protocol (QMP), the JSON control channel of QEMU.
///
/// The protocol is line oriented. After connecting, the emulator sends a greeting and stays in
/// capability negotiation mode until told otherwise; from then on the client issues commands, each
/// answered by exactly one reply, while the emulator interleaves asynchronous events.
///
/// The client is an actor. A dedicated thread performs the blocking reads and feeds complete lines
/// into a stream that is drained on the actor, so replies and events are processed strictly in the
/// order they were received. Commands are correlated with their replies through an identifier.
actor QMPClient {

    /// An asynchronous notification sent by the emulator.
    struct Event: Sendable {

        /// The name of the event, for example `STOP` or `SHUTDOWN`.
        let name: String

        /// The payload of the event, if it has one.
        let data: QMPValue?
    }

    /// A command waiting for its reply.
    private struct Request {
        let command: String
        let continuation: CheckedContinuation<QMPValue, any Error>
    }

    /// The events reported by the emulator, in order. The stream ends when the connection closes.
    nonisolated let events: AsyncStream<Event>

    /// The producing side of `events`.
    private let eventContinuation: AsyncStream<Event>.Continuation

    /// The connection to the emulator.
    private let socket: UnixSocket

    /// The commands that have been sent and not answered yet, by identifier.
    private var pending: [String: Request] = [:]

    /// The source of command identifiers.
    private var nextIdentifier = 0

    /// The caller suspended in `negotiate()` until the greeting arrives, if any.
    private var greetingWaiter: CheckedContinuation<Void, any Error>?

    /// Whether the greeting has been received.
    private var hasGreeting = false

    /// Whether the connection is gone.
    private var isClosed = false

    /// The task draining received lines on the actor.
    private var receiveTask: Task<Void, Never>?

    // MARK: - Connection

    /// Starts receiving. Has to be called once, before `negotiate()`.
    func start() {

        guard receiveTask == nil else { return }

        let (lines, lineContinuation) = AsyncStream<Data>.makeStream()
        let socket = self.socket

        Thread.detachNewThread {
            var buffer = Data()

            while let chunk = try? socket.read(upTo: 65536) {
                buffer.append(chunk)

                while let newline = buffer.firstIndex(of: 0x0A) {
                    let line = Data(buffer[buffer.startIndex..<newline])
                    buffer.removeSubrange(buffer.startIndex...newline)

                    if !line.isEmpty { lineContinuation.yield(line) }
                }
            }

            lineContinuation.finish()
        }

        receiveTask = Task { [weak self] in
            for await line in lines {
                await self?.receive(line)
            }

            await self?.connectionDidClose()
        }
    }

    /// Waits for the greeting and leaves capability negotiation mode.
    ///
    /// - Throws: `UnixSocketError.closed` if the emulator goes away first, which is what happens when
    ///   it rejects its command line.
    func negotiate() async throws {

        if !hasGreeting {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                if isClosed {
                    continuation.resume(throwing: UnixSocketError.closed)
                } else {
                    greetingWaiter = continuation
                }
            }
        }

        try await execute("qmp_capabilities")
    }

    /// Closes the connection. Pending commands fail and the event stream ends.
    func close() {
        socket.shutdown()
    }

    // MARK: - Commands

    /// Sends a command and waits for its reply.
    ///
    /// - Parameters:
    ///   - command: The name of the command.
    ///   - arguments: The arguments of the command, if it takes any.
    ///   - descriptor: An open descriptor to transfer together with the command. Commands such as
    ///     `getfd` and `add-fd` pick it up on the receiving side.
    /// - Returns: The value returned by the emulator.
    /// - Throws: `VZKitError.qemuCommandFailed` if the emulator rejects the command,
    ///   `UnixSocketError` if the connection fails.
    @discardableResult
    func execute(
        _ command: String,
        arguments: [String: QMPValue]? = nil,
        passing descriptor: Int32? = nil
    ) async throws -> QMPValue {

        guard !isClosed else { throw UnixSocketError.closed }

        let identifier = "request-\(nextIdentifier)"
        nextIdentifier += 1

        var message: [String: QMPValue] = [
            "execute": .string(command),
            "id": .string(identifier)
        ]

        if let arguments { message["arguments"] = .object(arguments) }

        let payload = try JSONEncoder().encode(QMPValue.object(message)) + Data([0x0A])

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<QMPValue, any Error>) in
            pending[identifier] = Request(command: command, continuation: continuation)

            do {
                try socket.write(payload, passing: descriptor)
            } catch {
                pending[identifier] = nil
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Receiving

    /// Dispatches one received line: the greeting, an event, or the reply to a pending command.
    private func receive(_ line: Data) {

        guard let message = try? JSONDecoder().decode(QMPValue.self, from: line) else { return }

        if message["QMP"] != nil {
            hasGreeting = true
            greetingWaiter?.resume()
            greetingWaiter = nil
            return
        }

        if let name = message["event"]?.stringValue {
            eventContinuation.yield(Event(name: name, data: message["data"]))
            return
        }

        guard let identifier = message["id"]?.stringValue,
              let request = pending.removeValue(forKey: identifier) else { return }

        if let error = message["error"] {
            let reason = error["desc"]?.stringValue ?? error["class"]?.stringValue ?? ""
            request.continuation.resume(throwing: VZKitError.qemuCommandFailed(request.command, reason))
        } else {
            request.continuation.resume(returning: message["return"] ?? .null)
        }
    }

    /// Fails everything that is still waiting once the connection is gone.
    private func connectionDidClose() {

        guard !isClosed else { return }
        isClosed = true

        greetingWaiter?.resume(throwing: UnixSocketError.closed)
        greetingWaiter = nil

        for request in pending.values {
            request.continuation.resume(throwing: UnixSocketError.closed)
        }

        pending.removeAll()
        eventContinuation.finish()
    }

    // MARK: - Initializers

    /// Creates a client on top of a connected socket.
    ///
    /// - Parameter socket: The control channel of an emulator.
    init(socket: UnixSocket) {
        let (events, eventContinuation) = AsyncStream<Event>.makeStream()

        self.socket = socket
        self.events = events
        self.eventContinuation = eventContinuation
    }
}
