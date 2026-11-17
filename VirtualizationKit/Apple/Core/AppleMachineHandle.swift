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

import Virtualization

@unsafe @preconcurrency import Combine

/// Owns the `VZVirtualMachine` of an Apple virtual machine and keeps every use of it on its queue.
///
/// Virtualization.framework requires every operation on a machine, apart from reading its `queue`, to
/// happen on the queue the machine was created with. This class is isolated to `VZKitActor`, whose
/// executor is that queue, so the compiler rejects any access from anywhere else. Being isolated to a
/// global actor also makes the class `Sendable`, which lets `AppleVirtualMachine`, a `Sendable` value,
/// hold it without declaring Virtualization's class `Sendable`.
///
/// Two things leave the queue, both on purpose:
/// - The changes of the machine's state, as plain `VZVirtualMachine.State` values, through `stateChanges`.
/// - The connection to a framebuffer view, which AppKit requires on the main actor. From macOS 27 that is
///   `VZVirtualMachineViewAdaptor`, which Virtualization.framework provides for this purpose; before, it
///   is the machine itself, through the one unchecked reference of this type.
@VZKitActor
final class AppleMachineHandle {

    /// The machine. Only reachable on its queue.
    let machine: VZVirtualMachine

    /// Connects a `VZVirtualMachineView` to the machine from macOS 27: a `VZVirtualMachineViewAdaptor`,
    /// type-erased because the type does not exist on earlier systems. `nil` before macOS 27.
    nonisolated let displayAdaptor: (any Sendable)?

    /// The machine, for `VZVirtualMachineView` before macOS 27, and for nothing else.
    ///
    /// The view runs on the main actor, and these systems offer no other way to hand it a machine that
    /// runs on another queue. This is the single place VirtualizationKit passes the machine across
    /// isolation without the compiler's checks; use `displayAdaptor` where it exists.
    nonisolated(unsafe) let machineForDisplay: VZVirtualMachine

    /// Broadcasts the changes of the machine's state, observed on its queue.
    private nonisolated let stateSubject = PassthroughSubject<VZVirtualMachine.State, Never>()

    /// The observation of the machine's state, once started.
    private var stateObservation: AnyCancellable?

    /// The changes of the machine's state. Nothing is emitted before `startObservingState()`.
    nonisolated var stateChanges: AnyPublisher<VZVirtualMachine.State, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    /// Creates the machine on its queue and wires its delegate there.
    ///
    /// - Parameters:
    ///   - configuration: The validated configuration. It is not used by the caller afterwards.
    ///   - delegate: The delegate receiving error callbacks.
    init(configuration: VZVirtualMachineConfiguration, delegate: AppleErrorDelegate) {

        let machine = VZVirtualMachine(
            configuration: configuration,
            queue: VZKitActor.queue
        )

        machine.delegate = delegate

        self.machine = machine
        unsafe self.machineForDisplay = machine

        if #available(macOS 27.0, *) {
            self.displayAdaptor = VZVirtualMachineViewAdaptor(virtualMachine: machine)
        } else {
            self.displayAdaptor = nil
        }
    }

    /// Starts observing the machine's state, on its queue.
    ///
    /// Only changes are observed: the `.initial` option would read the state at once, and a new machine is
    /// stopped anyway. Call this after subscribing to `stateChanges`, so that no change is missed.
    func startObservingState() {
        guard stateObservation == nil else { return }

        // `@Sendable`, so the closure carries no isolation: it runs on the machine's queue, called by KVO
        // rather than by the actor, and forwards a plain value.
        stateObservation = machine.publisher(for: \.state, options: [.new])
            .sink { @Sendable [stateSubject] state in stateSubject.send(state) }
    }

    // MARK: - Operations

    // Every operation calls Virtualization.framework synchronously, here on the machine's queue, and waits
    // for its completion handler. Swift's `async` variants are not used: in the Swift 6.0 language mode a
    // call to a non-isolated `async` function may leave the caller's queue, which Virtualization.framework
    // does not allow. The handlers are `@Sendable`, so they carry no isolation, and only the outcome, which
    // is `Sendable`, comes back.

    /// Starts the machine, or starts a macOS guest from macOS Recovery.
    ///
    /// - Parameter startsFromRecovery: Whether a macOS guest starts up from macOS Recovery.
    func start(fromRecovery startsFromRecovery: Bool = false) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            if startsFromRecovery {
                let options = VZMacOSVirtualMachineStartOptions()
                options.startUpFromMacOSRecovery = true
                machine.start(options: options, completionHandler: Self.resuming(continuation))
            } else {
                machine.start { @Sendable result in continuation.resume(with: result) }
            }
        }
    }

    /// Powers the machine off at once.
    func stop() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            machine.stop(completionHandler: Self.resuming(continuation))
        }
    }

    /// Asks the guest to shut itself down.
    func requestStop() throws {
        try machine.requestStop()
    }

    /// Pauses the machine.
    func pause() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            machine.pause { @Sendable result in continuation.resume(with: result) }
        }
    }

    /// Resumes the machine.
    func resume() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            machine.resume { @Sendable result in continuation.resume(with: result) }
        }
    }

    /// Attaches a USB device to a controller of the machine.
    @available(macOS 15.0, *)
    func attach<Device: VZUSBDevice>(_ device: Device, to controller: VZUSBController) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            controller.attach(device: device, completionHandler: Self.resuming(continuation))
        }
    }

    /// Detaches a USB device from a controller of the machine.
    @available(macOS 15.0, *)
    func detach<Device: VZUSBDevice>(_ device: Device, from controller: VZUSBController) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            controller.detach(device: device, completionHandler: Self.resuming(continuation))
        }
    }

    /// Installs macOS on the machine from a restore image.
    ///
    /// The installer operates on the machine, so it is created and run here, on the machine's queue. Its
    /// `Progress` is thread-safe and handed to the coordinator, which shows it as `.installing(progress:)`.
    ///
    /// - Parameters:
    ///   - restoreImage: The location of the IPSW restore image.
    ///   - coordinator: The coordinator showing the progress.
    /// - Throws: The error of the installation, unwrapped from its `underlyingErrors` where the framework
    ///   wraps it.
    func installMacOS(from restoreImage: URL, reportingTo coordinator: AppleStateCoordinator) async throws {

        let installer = VZMacOSInstaller(virtualMachine: machine, restoringFromImageAt: restoreImage)

        await coordinator.subscribe(installationProgress: installer.progress)

        // Swift may release an object after its last use. This use keeps the installer alive until the
        // installation has ended, not only until it has started.
        defer { withExtendedLifetime(installer) {} }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            installer.install { @Sendable result in
                switch result {
                case .failure(let error):
                    Task { @MainActor in
                        coordinator.eraseSubscription(for: .macOSInstaller, shouldReset: true)
                    }
                    continuation.resume(throwing: (error as NSError).underlyingErrors.first ?? error)

                case .success:
                    Task { @MainActor in
                        coordinator.eraseSubscription(for: .macOSInstaller)
                    }
                    continuation.resume()
                }
            }
        }
    }

    /// A completion handler reporting an optional error, resuming a continuation with it.
    private static func resuming(
        _ continuation: CheckedContinuation<Void, any Error>
    ) -> @Sendable ((any Error)?) -> Void {
        { error in
            if let error { continuation.resume(throwing: error) } else { continuation.resume() }
        }
    }
}
