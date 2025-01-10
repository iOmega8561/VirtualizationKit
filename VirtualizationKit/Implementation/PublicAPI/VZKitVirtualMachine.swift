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
//  VZKitVirtualMachine.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 15/05/24.
//

@preconcurrency import Virtualization

/// A data structure representing a Virtual Machine.
///
/// The `VZKitVirtualMachine` type is implemented as a struct to provide a lightweight, value-oriented
/// representation of a virtual machine instance. Rather than holding state directly, this struct
/// maintains references to other objects that are specifically designed to manage the virtual machine's
/// state. This approach ensures a clear separation of responsibilities: `VZKitVirtualMachine` serves as a
/// convenient interface for interacting with the virtual machine's state without itself being responsible
/// for state management. Using a struct here allows for efficient copying and passing of instances without
/// retaining a unique reference, and the conformance to `Sendable` ensures safe usage across concurrency
/// domains, as required by the `VZKitTemplatedVM` protocol interface.
///
/// - Note: This object can be created by calling the async `init()` directly, or by using the static factory method `createMachine()`.
///   The difference is that using the latter, the outcome of the initialization procedure will be encapsulated inside
///   a VZKitResult, allowing for graceful management of eventual errors. This is especially useful when working with a SwiftUI context,
///   in which you would need to store the error and later present this error to the user, so they can take action if needed.
///
/// - Important: A VZKitTemplate conforming object is not defined by this framework. It will be responsability of the
///   developer using these facilities to implement one and correctly use it with this generc data structure.
@dynamicMemberLookup public struct VZKitVirtualMachine<Template: VZKitTemplate>: VZKitTemplatedVM {
    
    /// Static factory method of this default implementation,
    ///
    /// - Parameters:
    ///   - template: the data transfer object containing all the information about the VM.
    ///
    /// - Returns:VZKitResult<Template> so that the caller can store any eventual error to something with it.
    public static func createMachine(_ template: Template) async -> VZKitResult<Template> {
        do {
            return try await .success(VZKitVirtualMachine(template: template))
            
        } catch { return .failure(error) }
    }
    
    /// A copy of the Data Transfer Object (DTO) that contains all essential information about the virtual machine (VM) template.
    ///
    /// This property holds an instance of `Template`, which provides the configuration details required
    /// for initializing and managing the virtual machine. The template includes specific settings and parameters
    /// that define the VM’s resources, behavior, and setup.
    public let template: Template
    
    /// A reference to the core `VZVirtualMachine` instance from the Virtualization framework.
    ///
    /// `vzVirtualMachine` serves as the primary interface for controlling the virtual machine, including
    /// operations like starting, stopping, installation procedures, and managing the graphical console.
    /// It encapsulates the underlying `VZVirtualMachine`, giving direct access to essential lifecycle management functionality.
    ///
    /// - Note: Although this property is scoped publicly, it's not recommended to interfere with it. It can be useful
    /// to have access to it in order to be able to use features from Virtualization.framework
    public let vzVirtualMachine: VZVirtualMachine
    
    /// Manages and tracks the current execution state of the virtual machine, pinned to the main actor.
    ///
    /// `stateCoordinator` is an instance of `VZKitObservableState` responsible for
    /// observing and updating the `VZVirtualMachine.State` of the virtual machine.
    /// Since `stateCoordinator` is tied to `@MainActor`, all state changes and updates are
    /// handled on the main thread, ensuring thread safety for UI updates and other main-thread operations.
    /// The `stateCoordinator` helps centralize and simplify state management within the VM, reducing the need
    /// for manual state tracking within the main view model.
    public let stateCoordinator: VZKitObservableState
    
    /// A reference to an instance of `VZKitDelegate`, responsible for handling VM events and updates.
    ///
    /// The `delegate` serves as an intermediary for receiving updates from the `VZVirtualMachine`,
    /// communicating events and state changes to other parts of the application. By connecting directly to
    /// the `VZVirtualMachine` instance, the `delegate` enables efficient event handling for lifecycle transitions
    /// and other VM-related activities.
    private let delegate: VZKitDelegate
    
    /// This method provides a standard way to send commands to the `VZVirtualMachine`
    /// and updates the shared state accordingly. If an error occurs, the state is safely reset before propagation.
    /// Since `VZError.virtualMachineLimitExceeded` has a confusing localizedDescription, this method traps it
    /// instead of propagating and throws `VZKitError.appleLimitExceeded`. Any case that `Command` provides
    /// is supported by this implementation.
    ///
    /// - Note: This method is pinned to `@VZKitActor` to ensure the operation is executed on
    /// the same queue that was used to create the `VZVirtualMachine` instance
    @VZKitActor public func performTransition(executing command: Command) async throws {
            
        await stateCoordinator.update(with: command.transitionState)
        
        do {
            switch command {
            case .start: try await vzVirtualMachine.start()
            case .stop: try await vzVirtualMachine.stop()
            case .pause: try await vzVirtualMachine.pause()
            case .resume: try await vzVirtualMachine.resume()
            case .install: try await VZKitMacOSInstaller(virtualMachine: self).restoreFromDiskImage()
            }
            
            if let state = command.finalState {
                await stateCoordinator.update(with: state)
            }
            
        } catch VZError.virtualMachineLimitExceeded {
            await stateCoordinator.rollback()
            throw VZKitError.appleLimitExceeded
            
        } catch { await stateCoordinator.rollback(); throw error }
    }

    /// The explicit, private, asynchronous init of the data structure. Uses an instance of `VZKitBuilder`
    /// to setup the `VZVirtualMachine` object and binds a new instance of `VirtualVZKitDelegate` to it.
    ///
    /// - Parameters:
    ///   - template: the data transfer object containing all the information about the VM.
    public init(template: Template) async throws {
        
        let builder = await VZKitBuilder(template: template)
        
        self.vzVirtualMachine = VZVirtualMachine(
            configuration: try await builder.createConfiguration(),
            queue: VZKitActor.queue
        )
        
        self.delegate = .init()
        self.template = template
        self.vzVirtualMachine.delegate = delegate
        self.stateCoordinator = await .init()
        
        await self.stateCoordinator.registerPublisher(
            delegate.statePublisher
        )
    }
    
    /// Provides dynamic access to the properties of `VZKitObservableState` through the `stateCoordinator`.
    ///
    /// This subscript allows you to access properties of the `VZKitObservableState` associated with
    /// the `stateCoordinator` instance as if they were directly part of the enclosing type. The
    /// `@dynamicMemberLookup` attribute enables seamless forwarding of property accesses, improving
    /// readability and simplifying interactions.
    ///
    /// ## Usage
    /// ```swift
    /// let state = virtualMachine.currentState // Accessing directly a property of `VZKitObservableState`
    /// ```
    ///
    /// - Parameter keyPath: A key path to a property of `VZKitObservableState`.
    /// - Returns: The value of the property at the specified key path.
    public subscript<T>(dynamicMember keyPath: KeyPath<VZKitObservableState, T>) -> T {
        stateCoordinator[keyPath: keyPath]
    }
}

@available(macOS 15.0, *)
@VZKitActor extension VZKitVirtualMachine {
    
    /// Attaches a removable USB disk to the virtual machine using a specified disk image.
    ///
    /// - Parameters:
    ///   - url: A `URL` pointing to the disk image file to be attached. The image can be
    ///   in a read-only or writable state depending on the configuration.
    /// - Returns: A `UUID` uniquely identifying the attached USB device.
    /// - Throws:
    ///   - `VZKitError.guestFeatureUnsupported`: If the virtual machine does not support XHCI USB controllers.
    ///   - Any error encountered during the creation or attachment of the USB mass storage device.
    /// - Note: This method is pinned to `@VZKitActor` to ensure the operation is executed on
    /// the same queue that was used to create the `VZVirtualMachine` instance
    public func attachRemovableUSBDisk(usingImageAt url: URL) async throws -> UUID {
        guard let controller = vzVirtualMachine.usbControllers.first else {
            throw VZKitError.unsupportedFeature(.xhciUSBHotSwap)
        }
        
        let massStorageDev = try VZUSBMassStorageDevice(
            configuration: .create(at: url, type: .readOnly)
        )
        
        try await controller.attach(device: massStorageDev)
    
        return massStorageDev.uuid
    }
    
    /// Detaches a previously attached removable USB disk from the virtual machine.
    ///
    /// - Parameters:
    ///   - id: The `UUID` identifying the USB mass storage device to detach.
    /// - Throws: An error if the detachment fails, such as:
    ///   - `VZKitError.guestFeatureUnsupported`: If the virtual machine does not support XHCI USB controllers,
    ///     or if the specified device cannot be found.
    ///   - `VZKitError.usbDeviceNotFound`: If the supplied id doesn't match any device that is currently attached to the VM.
    ///   - Other errors related to the detachment process.
    /// - Important: The `id` must correspond to a USB device previously attached via `attachRemovableUSBDisk(usingImageAt:)`.
    /// - Note: This method is pinned to `@VZKitActor` to ensure the operation is executed on
    /// the same queue that was used to create the `VZVirtualMachine` instance
    public func detachRemovableUSBDisk(identifiedBy id: UUID) async throws {
        guard let controller = vzVirtualMachine.usbControllers.first else {
            throw VZKitError.unsupportedFeature(.xhciUSBHotSwap)
        }
        
        guard let device = controller.usbDevices.first(where: { $0.uuid == id }) else {
            throw VZKitError.usbDeviceNotFound(id)
        }
        
        try await controller.detach(device: device)
    }
}
