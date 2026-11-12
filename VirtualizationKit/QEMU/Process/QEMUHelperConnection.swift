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

/// The outcome of an emulator process.
struct QEMUProcessExit: Sendable {

    /// The exit status, or the negated signal number if the process was killed by a signal.
    let status: Int32

    /// The tail of what the process wrote to its standard error.
    let diagnostics: String
}

/// An `async` façade over one connection to the helper service.
///
/// Each remote call is bridged to a continuation. The connection guarantees that, for a message with
/// a reply block, exactly one of the reply block and the proxy's error handler runs; the continuation
/// is therefore resumed exactly once, with either the reply or the connection error.
///
/// - Important: The type is `@unchecked Sendable` because its only state is the connection object,
///   which is documented to be thread-safe and is never mutated after initialization.
final class QEMUHelperConnection: @unchecked Sendable {

    /// The connection to the service. Invalidated when this object is released.
    private let connection: NSXPCConnection

    // MARK: - Remote Calls

    /// Hands a file over to the service for the next launch.
    ///
    /// - Parameter descriptor: An open descriptor. The caller keeps ownership of it.
    /// - Returns: The descriptor number the file will have inside the emulator process.
    func stage(descriptor: Int32) async throws -> Int32 {

        let slot: Int32 = try await withCheckedThrowingContinuation { continuation in

            guard let proxy = makeProxy(onError: { continuation.resume(throwing: $0) }) else {
                return continuation.resume(throwing: VZKitError.qemuHelperUnavailable)
            }

            proxy.stage(fileHandle: FileHandle(fileDescriptor: descriptor, closeOnDealloc: false)) {
                continuation.resume(returning: $0)
            }
        }

        guard slot >= 0 else {
            throw VZKitError.qemuHelperFailure("stage")
        }

        return slot
    }

    /// Starts an emulator process with the staged files.
    ///
    /// - Parameters:
    ///   - libraryName: The name of the system emulator library.
    ///   - arguments: The command line of the emulator.
    /// - Returns: The control channel of the new process. The caller owns the descriptor.
    func launch(libraryName: String, arguments: [String]) async throws -> Int32 {

        try await withCheckedThrowingContinuation { continuation in

            guard let proxy = makeProxy(onError: { continuation.resume(throwing: $0) }) else {
                return continuation.resume(throwing: VZKitError.qemuHelperUnavailable)
            }

            proxy.launch(libraryName: libraryName, arguments: arguments) { controlChannel, failure in

                // The received handle closes its descriptor when released, so keep a duplicate.
                guard let controlChannel else {
                    return continuation.resume(throwing: VZKitError.qemuHelperFailure(failure ?? ""))
                }

                let descriptor = dup(controlChannel.fileDescriptor)

                guard descriptor >= 0 else {
                    return continuation.resume(throwing: UnixSocketError.system(errno))
                }

                continuation.resume(returning: descriptor)
            }
        }
    }

    /// Waits for the emulator process to exit.
    ///
    /// - Returns: The outcome of the process.
    /// - Throws: The connection error if the service itself goes away first.
    func waitForExit() async throws -> QEMUProcessExit {

        try await withCheckedThrowingContinuation { continuation in

            guard let proxy = makeProxy(onError: { continuation.resume(throwing: $0) }) else {
                return continuation.resume(throwing: VZKitError.qemuHelperUnavailable)
            }

            proxy.waitForExit { status, diagnostics in
                continuation.resume(returning: .init(status: status, diagnostics: diagnostics))
            }
        }
    }

    /// Ends the emulator process. Failures are ignored: if the service is gone, so is the process.
    func terminate() async {

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in

            guard let proxy = makeProxy(onError: { _ in continuation.resume() }) else {
                return continuation.resume()
            }

            proxy.terminate { continuation.resume() }
        }
    }

    /// Tears the connection down. The service ends the emulator process when it notices.
    func invalidate() {
        connection.invalidate()
    }

    // MARK: - Helpers

    /// Creates a proxy whose failures are routed to a handler.
    ///
    /// - Parameter onError: Called instead of the reply block if the message cannot be delivered or
    ///   the service goes away before replying.
    /// - Returns: The proxy, or `nil` if the remote interface could not be bridged.
    private func makeProxy(onError: @escaping @Sendable (any Error) -> Void) -> (any QEMUHelperProtocol)? {
        connection.remoteObjectProxyWithErrorHandler(onError) as? any QEMUHelperProtocol
    }

    // MARK: - Initializers

    /// Connects to the helper service.
    ///
    /// The service is started on demand by the system when the first message is sent.
    ///
    /// - Parameter helper: The embedded service bundle.
    init(helper: QEMUHelperBundle) {
        self.connection = NSXPCConnection(serviceName: helper.serviceName)
        self.connection.remoteObjectInterface = NSXPCInterface(with: QEMUHelperProtocol.self)
        self.connection.resume()
    }

    deinit {
        connection.invalidate()
    }
}
