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

        /// Identifies the display connection of this power cycle, once it is attached.
        var displayGeneration: UInt64?
    }

    /// A drive hot-plugged while the machine runs, with everything it holds on to.
    private struct RemovableDevice {

        /// The power cycle the device was attached in. It disappears with the process.
        let sessionID: UUID

        /// The identifier of the USB device inside the emulator.
        let deviceID: String

        /// The name of the block node the device reads from.
        let nodeName: String

        /// The descriptor set holding the open image.
        let descriptorSet: Int64

        /// Keeps the image reachable inside the App Sandbox while the device is attached.
        let access: SecurityScopedAccess
    }

    /// A caller waiting for a particular event from the emulator.
    private struct EventWaiter {

        /// The power cycle the event is expected in.
        let sessionID: UUID

        /// The name of the event.
        let name: String

        /// Decides, from its payload, whether an event with the right name is the expected one.
        let matches: @Sendable (QMPValue?) -> Bool

        /// The outcome, if it was settled before anybody started waiting.
        var outcome: Result<Void, any Error>?

        /// The suspended caller, once there is one.
        var continuation: CheckedContinuation<Void, any Error>?
    }

    /// How long the emulator may take to confirm an operation it reports through an event.
    private static let eventTimeout: Duration = .seconds(10)

    /// How long a polite request to quit may take before the process is ended forcibly.
    private static let quitGracePeriod: Duration = .seconds(5)

    /// The command line and files of the machine.
    private let plan: QEMULaunchPlan

    /// The embedded helper service.
    private let helper: QEMUHelperBundle

    /// The owner of the observable execution state.
    private let coordinator: QEMUStateCoordinator

    /// The guest display, attached to the emulator for the duration of each power cycle.
    private let display: QEMUDisplay

    /// The name under which the display connection is handed to the emulator.
    private static let displayDescriptorName = "display0"

    /// The current power cycle, if the machine is on.
    private var session: Session?

    /// Whether a launch is in flight. Guards against a second `start` slipping in between its steps.
    private var isLaunching = false

    /// Whether the end of the current session was asked for, as opposed to being an accident.
    private var isStopRequested = false

    /// The drives attached while the machine runs, by the identifier handed to the caller.
    private var removableDevices: [UUID: RemovableDevice] = [:]

    /// The callers waiting for events, by an identifier of their own.
    private var eventWaiters: [UUID: EventWaiter] = [:]

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

        // Attached while the guest is still halted, so that the first frame it draws is seen.
        await attachDisplay(in: session.id)

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

        // Callers waiting for this event come first; the state mapping below is independent of them.
        for (token, waiter) in eventWaiters
        where waiter.sessionID == id && waiter.name == event.name && waiter.matches(event.data) {
            settleWaiter(token, with: .success(()))
        }

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

        // The current value, not the caller's copy, knows about the display attached since.
        guard let current = self.session, current.id == session.id else { return }

        self.session = nil
        self.isStopRequested = false

        await release(current)
        await coordinator.transition(to: .stopped)
    }

    /// Releases the resources of a session. Invalidating the helper connection ends the process.
    private func release(_ session: Session) async {
        session.eventTask?.cancel()

        // Nothing the emulator was going to report will come anymore.
        for (token, waiter) in eventWaiters where waiter.sessionID == session.id {
            settleWaiter(token, with: .failure(VZKitError.qemuCommandFailed(waiter.name, "the machine is off")))
        }

        // The hot-plugged drives went away with the process; their scope guards are released here.
        removableDevices = removableDevices.filter { $0.value.sessionID != session.id }

        if let displayGeneration = session.displayGeneration {
            await display.detach(generation: displayGeneration)
        }

        await session.control.close()
        session.helper.invalidate()
    }

    // MARK: - Display

    /// Connects the guest display to the emulator's display server.
    ///
    /// The server was started without listening anywhere. A connected socket pair is created here; one
    /// end is passed to the emulator over the control channel and handed to the server as a client,
    /// the other end is read by the display. A failure is reported through the display and does not
    /// affect the machine, which keeps running without a picture.
    ///
    /// - Parameter id: The session the display belongs to.
    private func attachDisplay(in id: UUID) async {

        guard let session, session.id == id else { return }

        let pair: (local: UnixSocket, peer: Int32)

        do {
            pair = try UnixSocket.makeDisplayPair()

        } catch {
            await display.report(VZKitError.qemuDisplayFailure("the display connection could not be created"))
            return
        }

        do {
            // The emulator keeps its own duplicate of the peer end; this one is closed either way.
            defer { _ = close(pair.peer) }

            try await send(
                "getfd",
                arguments: ["fdname": .string(Self.displayDescriptorName)],
                passing: pair.peer,
                in: session
            )

            try await send(
                "add_client",
                arguments: [
                    "protocol": .string("vnc"),
                    "fdname": .string(Self.displayDescriptorName),
                    "skipauth": .bool(true)
                ],
                in: session
            )

        } catch {
            pair.local.shutdown()
            await display.report(VZKitError.qemuDisplayFailure(error.localizedDescription))
            return
        }

        let generation = await display.attach(pair.local)

        // The session may have ended while the display was being attached.
        if self.session?.id == id {
            self.session?.displayGeneration = generation
        } else {
            await display.detach(generation: generation)
        }
    }

    // MARK: - Removable Media

    /// Attaches a disk image to the running machine as a removable USB drive.
    ///
    /// The image is opened read-only here, under a security-scope guard, and passed to the emulator
    /// over the control channel. The emulator never sees a path of the host.
    ///
    /// - Parameter url: The location of the image.
    /// - Returns: The identifier of the drive, to detach it later.
    /// - Throws: A localized error if the machine is off, the image cannot be opened, or the emulator
    ///   rejects the drive.
    func attachRemovableDisk(at url: URL) async throws -> UUID {

        guard let session else {
            throw VZKitError.qemuInvalidState(await coordinator.executionState.localizedName)
        }

        let access = SecurityScopedAccess(url: url)
        let file = try Self.open(.init(url: url, access: .readOnly))

        // The emulator keeps its own duplicate; this one is closed either way.
        defer { try? file.close() }

        let id = UUID()
        let base = "usb" + id.uuidString.replacingOccurrences(of: "-", with: "").prefix(12).lowercased()
        let deviceID = base + "-dev"
        let nodeName = base + "-img"

        let added = try await send(
            "add-fd",
            arguments: ["opaque": .string(deviceID)],
            passing: file.fileDescriptor,
            in: session
        )

        guard let descriptorSet = added["fdset-id"]?.integerValue else {
            throw VZKitError.qemuCommandFailed("add-fd", "the reply names no descriptor set")
        }

        do {
            try await send("blockdev-add", arguments: [
                "driver": .string("raw"),
                "node-name": .string(nodeName),
                "read-only": .bool(true),
                "file": .object([
                    "driver": .string("file"),
                    "node-name": .string(base + "-file"),
                    "filename": .string("/dev/fdset/\(descriptorSet)"),
                    "read-only": .bool(true)
                ])
            ], in: session)

        } catch {
            _ = try? await send("remove-fd", arguments: ["fdset-id": .integer(descriptorSet)], in: session)
            throw error
        }

        do {
            try await send("device_add", arguments: [
                "driver": .string("usb-storage"),
                "id": .string(deviceID),
                "drive": .string(nodeName),
                "bus": .string("xhci.0"),
                "removable": .bool(true)
            ], in: session)

        } catch {
            _ = try? await send("blockdev-del", arguments: ["node-name": .string(nodeName)], in: session)
            _ = try? await send("remove-fd", arguments: ["fdset-id": .integer(descriptorSet)], in: session)
            throw error
        }

        // The machine may have gone away in the meantime, and the drive with it.
        guard self.session?.id == session.id else {
            throw VZKitError.qemuInvalidState(await coordinator.executionState.localizedName)
        }

        removableDevices[id] = RemovableDevice(
            sessionID: session.id,
            deviceID: deviceID,
            nodeName: nodeName,
            descriptorSet: descriptorSet,
            access: access
        )

        return id
    }

    /// Detaches a drive attached through `attachRemovableDisk(at:)`.
    ///
    /// The device is unplugged first and its removal awaited; only then are the block node and the
    /// descriptor set released, and with them the image.
    ///
    /// - Parameter id: The identifier returned when the drive was attached.
    /// - Throws: `VZKitError.usbDeviceNotFound` for an unknown drive, or a localized error if the
    ///   emulator does not let the drive go.
    func detachRemovableDisk(identifiedBy id: UUID) async throws {

        guard let session, let device = removableDevices[id], device.sessionID == session.id else {
            throw VZKitError.usbDeviceNotFound(id)
        }

        // Taken out right away, so that a second request for the same drive does not overlap.
        removableDevices[id] = nil

        let token = expectEvent(named: "DEVICE_DELETED", in: session.id) { [deviceID = device.deviceID] data in
            data?["device"]?.stringValue == deviceID
        }

        do {
            try await send("device_del", arguments: ["id": .string(device.deviceID)], in: session)
            try await waitForEvent(token)

        } catch {
            discardWaiter(token)

            // Still attached as far as anybody knows; a later attempt may succeed.
            if self.session?.id == session.id { removableDevices[id] = device }
            throw error
        }

        guard self.session?.id == session.id else { return }

        // The guest no longer sees the drive. What is left is housekeeping inside the emulator.
        do {
            try await send("blockdev-del", arguments: ["node-name": .string(device.nodeName)], in: session)
            try await send("remove-fd", arguments: ["fdset-id": .integer(device.descriptorSet)], in: session)

        } catch {
            VZKitLogger.default.error("Cleanup after detaching a removable drive failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Events

    /// Registers interest in an event before the action that causes it, so that it cannot be missed.
    ///
    /// - Parameters:
    ///   - name: The name of the event.
    ///   - id: The session the event is expected in.
    ///   - matches: Selects the expected event among those with the right name.
    /// - Returns: A token to pass to `waitForEvent(_:)`, or to `discardWaiter(_:)`.
    private func expectEvent(
        named name: String,
        in id: UUID,
        where matches: @escaping @Sendable (QMPValue?) -> Bool
    ) -> UUID {
        let token = UUID()
        eventWaiters[token] = EventWaiter(sessionID: id, name: name, matches: matches)
        return token
    }

    /// Waits until a registered event arrives, the session ends or the confirmation times out.
    private func waitForEvent(_ token: UUID) async throws {

        let timeout = Task { [weak self] in
            try? await Task.sleep(for: Self.eventTimeout)

            guard !Task.isCancelled else { return }

            await self?.timeOutWaiter(token)
        }

        defer { timeout.cancel() }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in

            guard var waiter = eventWaiters[token] else {
                return continuation.resume(throwing: UnixSocketError.closed)
            }

            if let outcome = waiter.outcome {
                eventWaiters[token] = nil
                return continuation.resume(with: outcome)
            }

            waiter.continuation = continuation
            eventWaiters[token] = waiter
        }
    }

    /// Settles a waiter: resumes its caller, or records the outcome for when it starts waiting.
    private func settleWaiter(_ token: UUID, with outcome: Result<Void, any Error>) {

        guard var waiter = eventWaiters[token], waiter.outcome == nil else { return }

        if let continuation = waiter.continuation {
            eventWaiters[token] = nil
            continuation.resume(with: outcome)
        } else {
            waiter.outcome = outcome
            eventWaiters[token] = waiter
        }
    }

    /// Fails a waiter whose event has not arrived in time.
    private func timeOutWaiter(_ token: UUID) {
        guard let waiter = eventWaiters[token] else { return }
        settleWaiter(token, with: .failure(VZKitError.qemuCommandFailed(waiter.name, "no confirmation from the emulator")))
    }

    /// Forgets a waiter nobody is going to wait for.
    private func discardWaiter(_ token: UUID) {
        eventWaiters[token] = nil
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
    ///   - display: The guest display, attached while the machine is on.
    init(
        plan: QEMULaunchPlan,
        helper: QEMUHelperBundle,
        coordinator: QEMUStateCoordinator,
        display: QEMUDisplay
    ) {
        self.plan = plan
        self.helper = helper
        self.coordinator = coordinator
        self.display = display
    }
}
