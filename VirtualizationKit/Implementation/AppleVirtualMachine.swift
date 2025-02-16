//
//  Copyright (C) Giuseppe Rocco - All Rights Reserved
//  Unauthorized copying, modification or distribution of this source code,
//  via any medium is strictly prohibited and penally persecutable
//
//  This project and its source code are PROPRIETARY AND CONFIDENTIAL
//  Written by Giuseppe Rocco <giusepperocco38@gmail.com>, May 2024
//
//  -----------------------------------------------------------------------
//
//  AppleVirtualMachine.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 15/05/24.
//

@preconcurrency import Virtualization

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
        case start(options: VZVirtualMachineStartOptions)
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
            case .start:
                try await vzVirtualMachine.start()
            case .stop:
                try await vzVirtualMachine.stop()
            case .pause:
                try await vzVirtualMachine.pause()
            case .resume:
                try await vzVirtualMachine.resume()
            case .install:
                try await VZMacOSInstaller(virtualMachine: self)?.install()
            }
        } catch VZError.virtualMachineLimitExceeded {
            throw VZKitError.appleLimitExceeded
        }
    }

    /// Initializes a new `AppleVirtualMachine` by creating a `VZVirtualMachine` instance and delegating events.
    ///
    /// - Parameter template: The configuration object that describes how the virtual machine should be built.
    /// - Throws: Errors encountered while generating the VM configuration, setting up the virtualization
    ///           framework, or initializing the event delegation process.
    public init(template: Template) async throws {
        
        let builder = await AppleConfigurationBuilder(template: template)
        
        self.vzVirtualMachine = VZVirtualMachine(
            configuration: try await builder.createConfiguration(),
            queue: VZKitActor.queue
        )
        
        self.errorDelegate = .init()
        self.template = template
        self.vzVirtualMachine.delegate = errorDelegate
        self.stateCoordinator = await .init()
        
        await self.stateCoordinator.registerPublisher(errorDelegate.errorSubject)
        await self.stateCoordinator.registerPublisher(vzVirtualMachine.publisher(for: \.state))
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
        
        let massStorageDev = try VZUSBMassStorageDevice(
            configuration: .create(at: url, type: .readOnly)
        )
        
        try await controller.attach(device: massStorageDev)
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
    }
}
