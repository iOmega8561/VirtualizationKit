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

/// Drives the emulator process behind one virtual machine.
///
/// The engine owns everything that exists only while a guest is powered on: the connection to the
/// helper service, the emulator process on the other side of it, and the control channel into that
/// process. It translates the high-level actions of the backend into helper calls and control
/// commands, and feeds the resulting state changes to the coordinator.
///
/// It is an actor of its own rather than a client of the framework's global actor. That actor
/// serializes on the single queue all Apple-backend machines share; an emulator needs no such queue,
/// and parking its (potentially slow) lifecycle operations there would stall unrelated machines.
///
/// ## Lifecycle
///
/// A power cycle is represented by a *session*. `start` creates one, the exit of the emulator process
/// ends it, and at most one exists at a time. Because an actor may interleave calls at every
/// suspension point, each asynchronous step re-checks that the session it started with is still the
/// current one before acting on its outcome.
actor QEMUEngine {

    /// The resources of one power cycle.
    private struct Session {

        /// Distinguishes this power cycle from earlier and later ones.
        let id: UUID

        /// The connection to the helper service hosting the emulator process.
        let helper: QEMUHelperConnection

        /// The control channel into the emulator.
        let control: QMPClient

        /// Completes, with the outcome, once the emulator process is gone and has been accounted for.
        let exitTask: Task<QEMUProcessExit, Never>

        /// Forwards control channel events to the engine.
        var eventTask: Task<Void, Never>?
    }

    /// How long a polite request to quit may take before the process is ended forcibly.
    private static let quitGracePeriod: Duration = .seconds(5)

    /// The command line and files of the machine.
    private let plan: QEMULaunchPlan

    /// The embedded helper service.
    private let helper: QEMUHelperBundle

    /// The owner of the observable execution state.
    private let coordinator: QEMUStateCoordinator

    /// The current power cycle, if the machine is on.
    private var session: Session?

    /// Whether a launch is in flight. Guards against a second `start` slipping in between its steps.
    private var isLaunching = false

    /// Whether the end of the current session was asked for, as opposed to being an accident.
    private var isStopRequested = false

    // MARK: - Actions

    /// Powers the machine on.
    ///
    /// - Parameter paused: Whether to leave the guest halted at its first instruction.
    /// - Throws: A localized error if the machine is already on, the helper service is unavailable,
    ///   or the emulator exits during start-up (in which case its diagnostics are included).
    func start(paused: Bool) async throws {

        guard session == nil, !isLaunching else {
            throw VZKitError.qemuInvalidState(await coordinator.executionState.localizedName)
        }

        isLaunching = true
        defer { isLaunching = false }

        await coordinator.transition(to: .starting)

        let session: Session

        do {
            session = try await launch()

        } catch {
            await coordinator.transition(to: .stopped)
            throw error
        }

        // From here on the exit of the process is handled by `processDidExit`, which is also what
        // reports the failure if the process dies during the remaining steps.
        self.session = session
        self.isStopRequested = false
        self.session?.eventTask = Task { [weak self, id = session.id, events = session.control.events] in
            for await event in events {
                await self?.handle(event, in: id)
            }
        }

        do {
            if paused {
                await coordinator.transition(to: .paused)
            } else {
                try await send("cont", in: session)
                await transition(to: .running, in: session.id)
            }

        } catch {
            await abort(session)
            throw error
        }
    }

    /// Powers the machine off without involving the guest.
    ///
    /// The emulator is first asked to quit, which lets it flush and close its disk images. If it has not
    /// exited after a grace period, the helper service ends the process.
    func stop() async throws {

        guard let session else {
            throw VZKitError.qemuInvalidState(await coordinator.executionState.localizedName)
        }

        isStopRequested = true
        await transition(to: .stopping, in: session.id)

        // A failure here only means the process is already on its way out.
        _ = try? await session.control.execute("quit")

        let escalation = Task { [helper = session.helper] in
            try? await Task.sleep(for: Self.quitGracePeriod)

            if !Task.isCancelled { await helper.terminate() }
        }

        _ = await session.exitTask.value
        escalation.cancel()
    }

    /// Halts the guest processors.
    func pause() async throws {

        guard let session else {
            throw VZKitError.qemuInvalidState(await coordinator.executionState.localizedName)
        }

        await transition(to: .pausing, in: session.id)

        do {
            try await send("stop", in: session)
            await transition(to: .paused, in: session.id)

        } catch {
            await transition(to: .running, in: session.id)
            throw error
        }
    }

    /// Lets the guest processors run again.
    func resume() async throws {

        guard let session else {
            throw VZKitError.qemuInvalidState(await coordinator.executionState.localizedName)
        }

        await transition(to: .resuming, in: session.id)

        do {
            try await send("cont", in: session)
            await transition(to: .running, in: session.id)

        } catch {
            await transition(to: .paused, in: session.id)
            throw error
        }
    }

    /// Presses the virtual power button, asking the guest to shut itself down.
    func requestPowerDown() async throws {

        guard let session else {
            throw VZKitError.qemuInvalidState(await coordinator.executionState.localizedName)
        }

        try await send("system_powerdown", in: session)
    }

    /// Resets the machine, as the reset button of a physical one would.
    func reset() async throws {

        guard let session else {
            throw VZKitError.qemuInvalidState(await coordinator.executionState.localizedName)
        }

        try await send("system_reset", in: session)
    }

    // MARK: - Launch

    /// Opens the files of the machine, starts the emulator and establishes the control channel.
    ///
    /// - Returns: A session whose guest is created but halted.
    private func launch() async throws -> Session {

        let connection = QEMUHelperConnection(helper: helper)

        do {
            // The files are opened here, in the process that holds the rights to them, and stay open
            // until the emulator has been started with its own duplicates.
            var files: [FileHandle] = []

            for (index, source) in plan.descriptors.enumerated() {
                let file = try Self.open(source)
                files.append(file)

                let slot = try await connection.stage(descriptor: file.fileDescriptor)

                guard slot == QEMULaunchPlan.firstBrokeredDescriptor + Int32(index) else {
                    throw VZKitError.qemuHelperFailure("unexpected descriptor \(slot)")
                }
            }

            let controlDescriptor = try await connection.launch(
                libraryName: plan.libraryName,
                arguments: plan.arguments
            )

            files.removeAll()

            let id = UUID()
            let control = QMPClient(socket: UnixSocket(adopting: controlDescriptor))

            let exitTask = Task { [weak self] in
                let outcome: QEMUProcessExit

                do {
                    outcome = try await connection.waitForExit()
                } catch {
                    // The helper service itself went away, and the emulator with it.
                    outcome = .init(status: -1, diagnostics: error.localizedDescription)
                }

                await self?.processDidExit(outcome, in: id)
                return outcome
            }

            await control.start()

            do {
                try await control.negotiate()

            } catch {
                // An emulator that never speaks has rejected its command line or failed to
                // initialise. Make sure it is gone, then report what it had to say.
                await connection.terminate()
                await control.close()

                let outcome = await exitTask.value
                throw VZKitError.qemuProcessExited(outcome.status, outcome.diagnostics)
            }

            return Session(id: id, helper: connection, control: control, exitTask: exitTask)

        } catch {
            connection.invalidate()
            throw error
        }
    }

    /// Opens one of the machine's files with the access mode its drive is configured with.
    private static func open(_ source: QEMUDescriptorSource) throws -> FileHandle {
        do {
            switch source.access {
            case .readOnly: return try FileHandle(forReadingFrom: source.url)
            case .readWrite: return try FileHandle(forUpdating: source.url)
            }

        } catch { throw VZKitError.qemuStorageFailedSetup(source.url.lastPathComponent) }
    }

    // MARK: - Session Events

    /// Reacts to a notification from the emulator.
    private func handle(_ event: QMPClient.Event, in id: UUID) async {

        switch event.name {
        case "STOP": await transition(to: .paused, in: id)
        case "RESUME": await transition(to: .running, in: id)
        case "SHUTDOWN": await transition(to: .stopping, in: id)
        default: break
        }
    }

    /// Accounts for the end of the emulator process, whatever caused it.
    private func processDidExit(_ outcome: QEMUProcessExit, in id: UUID) async {

        guard let session, session.id == id else { return }

        let wasRequested = isStopRequested

        self.session = nil
        self.isStopRequested = false

        await release(session)

        if wasRequested || outcome.status == 0 {
            await coordinator.transition(to: .stopped)
        } else {
            await coordinator.transition(to: .error(
                error: VZKitError.qemuProcessExited(outcome.status, outcome.diagnostics)
            ))
        }
    }

    /// Ends a session whose start-up could not be completed.
    private func abort(_ session: Session) async {

        guard self.session?.id == session.id else { return }

        self.session = nil
        self.isStopRequested = false

        await release(session)
        await coordinator.transition(to: .stopped)
    }

    /// Releases the resources of a session. Invalidating the helper connection ends the process.
    private func release(_ session: Session) async {
        session.eventTask?.cancel()
        await session.control.close()
        session.helper.invalidate()
    }

    // MARK: - Helpers

    /// Publishes a state, provided the session it belongs to is still the current one.
    private func transition(to state: ExecutionState, in id: UUID) async {
        guard session?.id == id else { return }
        await coordinator.transition(to: state)
    }

    /// Sends a control command, reporting a lost connection as a localized error.
    @discardableResult
    private func send(
        _ command: String,
        arguments: [String: QMPValue]? = nil,
        passing descriptor: Int32? = nil,
        in session: Session
    ) async throws -> QMPValue {
        do {
            return try await session.control.execute(command, arguments: arguments, passing: descriptor)

        } catch is UnixSocketError {
            throw VZKitError.qemuCommandFailed(command, "the control channel is closed")
        }
    }

    // MARK: - Initializers

    /// Creates the engine of a machine that is off.
    ///
    /// - Parameters:
    ///   - plan: The command line and files of the machine.
    ///   - helper: The embedded helper service.
    ///   - coordinator: The owner of the observable execution state.
    init(plan: QEMULaunchPlan, helper: QEMUHelperBundle, coordinator: QEMUStateCoordinator) {
        self.plan = plan
        self.helper = helper
        self.coordinator = coordinator
    }
}
