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
import Testing
@testable import VirtualizationKit

/// Plays the emulator on the other end of a socket pair: greets, then answers every command except the
/// ones it is told to ignore.
private final class FakeEmulator: @unchecked Sendable {

    private let socket: UnixSocket
    private let ignored: Set<String>
    private let lock = NSLock()
    private var identifiers: [String: String] = [:]

    init(socket: UnixSocket, ignoring ignored: Set<String> = []) {
        self.socket = socket
        self.ignored = ignored
    }

    func run() {
        Thread.detachNewThread { [self] in
            send(#"{"QMP": {"version": {}, "capabilities": []}}"#)

            var buffer = Data()
            while let chunk = try? socket.read(upTo: 4096) {
                buffer.append(chunk)

                while let newline = buffer.firstIndex(of: 0x0A) {
                    let line = buffer[buffer.startIndex..<newline]
                    buffer.removeSubrange(buffer.startIndex...newline)

                    guard let message = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                          let command = message["execute"] as? String,
                          let identifier = message["id"] as? String else { continue }

                    lock.withLock { identifiers[command] = identifier }
                    if !ignored.contains(command) { reply(to: identifier) }
                }
            }
        }
    }

    /// Answers the last request for a command, even if the client has stopped waiting for it.
    func lateReply(to command: String) {
        if let identifier = lock.withLock({ identifiers[command] }) { reply(to: identifier) }
    }

    private func reply(to identifier: String) {
        send(#"{"return": {}, "id": "\#(identifier)"}"#)
    }

    private func send(_ line: String) {
        try? socket.write(Data((line + "\n").utf8))
    }

    func stop() {
        socket.shutdown()
    }
}

@Suite("QMP client")
struct QMPClientTests {

    private func connect(ignoring ignored: Set<String> = []) async throws -> (QMPClient, FakeEmulator) {
        let pair = try UnixSocket.makePair()
        let emulator = FakeEmulator(socket: UnixSocket(adopting: pair.peer), ignoring: ignored)
        emulator.run()

        let client = QMPClient(socket: pair.local)
        await client.start()
        try await client.negotiate()
        return (client, emulator)
    }

    @Test("Commands are answered")
    func answered() async throws {
        let (client, emulator) = try await connect()
        defer { emulator.stop() }

        _ = try await client.execute("query-status")
        await client.close()
    }

    @Test("A command without a reply fails at its deadline, and the client stays usable")
    func deadline() async throws {
        let (client, emulator) = try await connect(ignoring: ["stop"])
        defer { emulator.stop() }

        let started = ContinuousClock.now
        await #expect {
            try await client.execute("stop", timeout: .milliseconds(300))
        } throws: { error in
            guard case VZKitError.qemuCommandFailed("stop", let reason) = error else { return false }
            return reason.contains("no reply")
        }
        let waited = ContinuousClock.now - started
        #expect(waited >= .milliseconds(300) && waited < .seconds(3))

        // A reply arriving after the deadline is ignored, and later commands still work.
        emulator.lateReply(to: "stop")
        _ = try await client.execute("query-status")
        await client.close()
    }

    @Test("Closing the connection fails pending commands at once")
    func close() async throws {
        let (client, emulator) = try await connect(ignoring: ["quit"])
        defer { emulator.stop() }

        let pending = Task { try await client.execute("quit", timeout: .seconds(30)) }
        try await Task.sleep(for: .milliseconds(100))

        let started = ContinuousClock.now
        await client.close()
        await #expect(throws: UnixSocketError.self) { try await pending.value }
        #expect(ContinuousClock.now - started < .seconds(2))
    }
}
