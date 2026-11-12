//
//  Copyright 2025 Giuseppe Rocco
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
//  -----------------------------------------------------------------------
//
//  AppleVirtualMachine.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 15/05/24.
//

import Virtualization

/// A specialized struct implementing `VirtualMachine` for the Apple Virtualization framework.
///
/// `AppleVirtualMachine` encapsulates configuration details, state management, and direct interaction
/// with a `VZVirtualMachine` instance. By composing references to a `TransferableTemplate`, a state coordinator,
/// and a delegate, it provides a clear separation of responsibilities. This lightweight, value-oriented
/// design allows easy passing and copying of the virtual machine interface without duplicating large
/// internal state, while still adhering to `Sendable` requirements.
///
/// ## Concurrency
/// - Methods like `execute(action:)` are pinned to `@VZKitActor`, ensuring they run on the same queue
///   used to create the underlying `VZVirtualMachine`.
/// - Conforming to `Sendable` enforces safe usage of `AppleVirtualMachine` instances across concurrency
///   domains, provided your `Template` also respects these constraints.
///
/// ## Separation of Concerns
/// - **`template`**: Contains the VM configuration details (memory, CPU, storage, etc.). This is provided
///   by user-defined types conforming to `TransferableTemplate`.
/// - **`stateCoordinator`**: Manages execution state (`ExecutionState`) and broadcasts updates through
///   Combine publishers. Marked `@MainActor` for thread-safe UI integration.
/// - **`vzVirtualMachine`**: The primary Apple Virtualization object, handling lifecycle actions like
///   start, stop, pause, and resume.
/// - **`delegate`**: Listens to events from the Virtualization framework and communicates them back
///   to `stateCoordinator`.
///
/// - Note: This struct is not responsible for storing or mutating substantial state. Instead, it
///   references specialized components that each manage a specific aspect of the VM's lifecycle.
public struct AppleVirtualMachine<Template: TransferableTemplate>: VirtualMachine {
    
    /// An enum of high-level actions that can be performed on the Apple Virtual Machine.
    ///
    /// Examples include:
    /// - `.start(options: ... )`: Boot the VM using the specified launch options.
    /// - `.stop`: Gracefully shut down the VM.
    /// - `.pause`: Suspend the VM.
    /// - `.resume`: Resume the VM from a paused state.
    /// - `.install`: Run an installation procedure, typically for macOS guests.
    public enum Action: ExecutableAction {
        case start(options: VZVirtualMachineStartOptions?)
        case stop
        case pause
        case resume
        case install
    }
    
    /// The configuration template describing how to set up and manage the VM.
    ///
    /// `template` should contain details such as memory allocation, CPU cores, disk images,
    /// and any other configuration data relevant to the virtual machine. It must conform
    /// to `TransferableTemplate`.
    public let template: Template
    
    /// Manages the VM’s execution state and communicates changes on the main actor.
    ///
    /// `stateCoordinator` tracks `ExecutionState` updates and provides Combine publishers
    /// for consumers such as SwiftUI views. Its `@MainActor` isolation ensures state changes
    /// are safe for UI binding.
    public let stateCoordinator: AppleStateCoordinator
    
    /// The core Apple Virtualization object responsible for lifecycle operations.
    ///
    /// `vzVirtualMachine` underlies all major operations like starting, stopping, or installing
    /// an OS onto the virtual machine. While publicly scoped, direct calls on this property
    /// are generally discouraged in favor of higher-level methods provided by this struct.
    let vzVirtualMachine: VZVirtualMachine
    
    /// Handles error event callbacks from the `VZVirtualMachine` and forwards them to other components.
    ///
    /// `errorDelegate` observes the VM’s lifecycle and propagates state changes or errors
    /// to `stateCoordinator`. Conforming code typically does not need to interact with
    /// this delegate directly.
    private let errorDelegate: AppleErrorDelegate
    
    /// Keeps the install media reachable inside the App Sandbox for as long as the machine exists.
    ///
    /// The media is referenced by the configuration (as an attached image) and by the installer, both of
    /// which open it long after this value has been created.
    private let installMediaAccess: SecurityScopedAccess?
    
    /// Keeps the images of hot-plugged removable devices reachable while they are attached.
    private let removableMediaAccess: SecurityScopeRegistry
    
    /// Executes a high-level VM action and manages resulting state changes within the same actor context.
    ///
    /// Supported actions include `.start`, `.stop`, `.pause`, `.resume`, and `.install`. Upon encountering
    /// a `VZError.virtualMachineLimitExceeded`, this method rethrows a more descriptive `VZKitError.appleLimitExceeded`.
    ///
    /// - Parameter action: An instance of `Action` describing the requested operation (start, stop, etc.).
    /// - Throws: `VZKitError.appleLimitExceeded` if the virtual machine limit is exceeded, or other errors
    ///           specific to the operation or Virtualization framework.
    @VZKitActor public func execute(action: Action) async throws {
        do {
            switch action {
            case .start(let vzStartOptions?):
                try await vzVirtualMachine.start(options: vzStartOptions)
            case .start(nil):
                try await vzVirtualMachine.start()
            case .stop:
                try await vzVirtualMachine.stop()
            case .pause:
                try await vzVirtualMachine.pause()
            case .resume:
                try await vzVirtualMachine.resume()
            case .install:
                try await VZMacOSInstaller(virtualMachine: self)?.install(stateCoordinator)
            }
        } catch VZError.virtualMachineLimitExceeded {
            
            if await self.executionState != .stopped {
                // Note:
                //
                // Historically, `VZVirtualMachine` would automatically transition to `.stopped`
                // after termination, and this state change would propagate via KVO observation.
                // In recent macOS versions, this no longer occurs — the VM state appears to
                // remain stuck in its last transitional state even after the VM has fully stopped.
                // The cause is unclear; it may be a change in Virtualization.framework's internal state
                // management or a regression in macOS.
                //
                // Workaround: explicitly reset the execution state here to keep the coordinator
                // in sync with the actual VM state.
                await self.stateCoordinator.resetExecutionState()
            }

            throw VZKitError.appleLimitExceeded

        } catch {

            // Any other failure can strand the coordinator in a transitional state as well:
            // the hypervisor reports `.error`, which the state observation cannot represent.
            // Read the real state here, on the machine's queue, and let the coordinator catch up.
            await self.stateCoordinator.reconcile(with: vzVirtualMachine.state)

            throw error
        }
    }

    /// Initializes a new `AppleVirtualMachine` by creating a `VZVirtualMachine` instance and delegating events.
    ///
    /// - Parameter template: The configuration object that describes how the virtual machine should be built.
    /// - Throws: Errors encountered while generating the VM configuration, setting up the virtualization
    ///           framework, or initializing the event delegation process.
    public init(template: Template) async throws {
        
        // Must precede the configuration: building it already opens the install media.
        self.installMediaAccess = template.bootableInstallMedia.map { SecurityScopedAccess(url: $0) }
        self.removableMediaAccess = .init()
        
        let builder = await AppleConfigurationBuilder(template: template)
        let configuration = try await builder.createConfiguration()
        let errorDelegate = AppleErrorDelegate()
        
        self.vzVirtualMachine = await Self.makeVirtualMachine(
            configuration: configuration,
            delegate: errorDelegate
        )
        
        self.errorDelegate = errorDelegate
        self.template = template
        self.stateCoordinator = await .init()
        
        await self.stateCoordinator.subscribe(errorDelegate.errorSubject)
        
        // The observation must not read the machine from the main thread, which is what the
        // `.initial` option does at subscription time. A new machine is always stopped, so the
        // first value is supplied here instead and only real changes are observed.
        await self.stateCoordinator.subscribe(
            vzVirtualMachine.publisher(for: \.state, options: [.new]).prepend(.stopped)
        )
    }
    
    /// Creates the hypervisor object and wires its delegate on the queue the machine operates on.
    ///
    /// Every operation on a `VZVirtualMachine`, including the assignment of its delegate, has to happen
    /// on the queue handed to its initializer. The public initializer of this type is not isolated, so
    /// the work is funnelled through the global actor, whose executor is that very queue.
    ///
    /// - Parameters:
    ///   - configuration: The validated configuration. It is not used by the caller afterwards.
    ///   - delegate: The delegate receiving error callbacks.
    /// - Returns: The configured machine.
    @VZKitActor
    private static func makeVirtualMachine(
        configuration: VZVirtualMachineConfiguration,
        delegate: AppleErrorDelegate
    ) -> VZVirtualMachine {
        
        let virtualMachine = VZVirtualMachine(
            configuration: configuration,
            queue: VZKitActor.queue
        )
        
        virtualMachine.delegate = delegate
        return virtualMachine
    }
}

@available(macOS 15.0, *)
@VZKitActor public extension AppleVirtualMachine {
    
    /// Attaches a removable USB mass storage device to the VM from a specified disk image.
    ///
    /// This method finds the first available XHCI USB controller on the virtual machine and attaches
    /// a `VZUSBMassStorageDevice` representing the given disk image. A read-only image is commonly
    /// used for installation media or data discs.
    ///
    /// - Parameter url: A file URL referencing the disk image to be attached.
    /// - Returns: A `UUID` uniquely identifying the attached USB device for future tracking or removal.
    /// - Throws:
    ///   - `VZKitError.unsupportedFeature(.xhciUSBHotSwap)` if no suitable USB controller is found.
    ///   - Other Apple Virtualization–related errors if attachment fails.
    func attachRemovableUSBDisk(usingImageAt url: URL) async throws -> UUID {
        guard let controller = vzVirtualMachine.usbControllers.first else {
            throw VZKitError.unsupportedFeature(.xhciUSBHotSwap)
        }
        
        // Released again if anything below throws, kept for as long as the device stays attached.
        let access = SecurityScopedAccess(url: url)
        
        let massStorageDev = try VZUSBMassStorageDevice(
            configuration: .create(at: url, type: .readOnly)
        )
        
        try await controller.attach(device: massStorageDev)
        removableMediaAccess.retain(access, for: massStorageDev.uuid)
        return massStorageDev.uuid
    }
    
    /// Detaches a previously attached removable USB mass storage device from the VM.
    ///
    /// This method searches the first XHCI USB controller for the device matching the provided `UUID`.
    /// If found, it detaches the mass storage device, making it no longer available within the VM.
    ///
    /// - Parameter id: The `UUID` used to identify the USB device during attachment.
    /// - Throws:
    ///   - `VZKitError.unsupportedFeature(.xhciUSBHotSwap)` if no suitable USB controller is found.
    ///   - `VZKitError.usbDeviceNotFound(id)` if the specified device is not attached.
    ///   - Other errors originating from the Apple Virtualization framework during detachment.
    func detachRemovableUSBDisk(identifiedBy id: UUID) async throws {
        guard let controller = vzVirtualMachine.usbControllers.first else {
            throw VZKitError.unsupportedFeature(.xhciUSBHotSwap)
        }
        
        guard let device = controller.usbDevices.first(where: { $0.uuid == id }) else {
            throw VZKitError.usbDeviceNotFound(id)
        }
        
        try await controller.detach(device: device)
        removableMediaAccess.release(id)
    }
}
