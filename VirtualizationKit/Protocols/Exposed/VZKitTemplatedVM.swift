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
//  Created by Giuseppe Rocco on 14/05/24.
//

import Virtualization

/// A protocol defining the requirements for a templated virtual machine within the `VZKit` framework.
///
/// The `VZKitTemplatedVM` protocol specifies the essential properties and methods required to manage and interact
/// with a virtual machine. This includes handling configuration templates, managing state transitions, and supporting
/// dynamic operations like attaching and detaching removable USB devices. Conforming types integrate seamlessly
/// with the `Virtualization` framework while providing flexibility for custom implementations.
///
/// ## Features
/// - **Template-Based Configuration**: Enables initialization and management of virtual machines using template data.
/// - **State Management**: Provides support for tracking and updating the machine's execution state.
/// - **Dynamic Operations**: Includes functionality to attach and detach removable USB disks.
/// - **Action Execution**: Standardizes how actions like starting, stopping, or pausing are dispatched to the virtual machine.
///
/// ## Associated Types
/// - `ExecutableAction`: Defines the actions that can be performed on the virtual machine (e.g., `.start`, `.stop`).
/// - `Template`: Represents the configuration template used to set up and manage the virtual machine.
/// - `StateCoordinator`: Manages the virtual machine's state and integrates with observers (e.g., UI updates).
///
/// ## Use Cases
/// - Managing the lifecycle and operations of a virtual machine, including power commands.
/// - Tracking state and progress using a centralized state coordinator.
/// - Configuring the virtual machine using a predefined template.
/// - Dynamically managing attached devices like USB mass storage.
///
/// ## Example
/// ```swift
/// struct MyTemplatedVM: VZKitTemplatedVM {
///     typealias ExecutableAction = MyVMAction
///     typealias Template = MyVMTemplate
///     typealias StateCoordinator = MyStateCoordinator
///
///     var template: MyVMTemplate
///     var vzVirtualMachine: VZVirtualMachine
///     var stateCoordinator: MyStateCoordinator
///
///     func performTransition(executing action: MyVMAction) async throws {
///         // Handle VM transition logic here
///     }
///
///     func attachRemovableUSBDisk(usingImageAt url: URL) async throws -> UUID {
///         // Handle USB disk attachment
///     }
///
///     func detachRemovableUSBDisk(identifiedBy id: UUID) async throws {
///         // Handle USB disk detachment
///     }
/// }
/// ```
///
/// ## Concurrency
/// The protocol supports asynchronous methods for state transitions and device management, ensuring safe and efficient
/// execution in concurrent contexts.
///
/// ## Availability
/// - The USB disk attachment and detachment methods are available starting from macOS 15.0.
///
/// - Note: Conforming types must be `Sendable` to ensure thread safety in Swift's concurrency model.
public protocol VZKitTemplatedVM: Sendable {
    
    // MARK: - Associated Types
    
    /// A type representing the possible action to be dispatched to the virtual machine
    ///
    /// `ExecutableAction` can be anything conforming to `Sendable`. For example, this can be an
    /// enum that wraps all the possible power commands like: `.start`, `.stop`, `.pause`, and `.resume`.
    /// The specific is left to the developer’s discretion to suit the application’s needs.
    associatedtype ExecutableAction: Sendable
    
    /// A type representing the template data required to configure the virtual machine.
    ///
    /// `Template` must conform to `VZKitTemplate`, which provides the essential configuration details
    /// for initializing or managing a virtual machine, such as resource allocations and other setup parameters.
    associatedtype Template: VZKitTemplate
    
    /// A type representing the state manager responsible for tracking the virtual machine’s execution state.
    ///
    /// `StateCoordinator` must conform to `VZKitStateCoordinator` and is responsible for holding and
    /// updating the VM’s state information. The state manager ensures that any state changes are safely managed,
    /// supporting UI updates and other components that depend on the VM’s current state.
    associatedtype StateCoordinator: VZKitStateCoordinator
    
    // MARK: - Properties
    
    /// The template data used to configure the virtual machine.
    ///
    /// `template` holds a copy of the data transfer object (DTO) required to initialize and manage the virtual machine.
    /// It provides configuration information, such as memory size, CPU count, and storage configuration.
    var template: Template { get }

    /// A reference to the `VZVirtualMachine` instance, providing core functionality for VM management.
    ///
    /// `vzVirtualMachine` is the main object from the `Virtualization` framework that encapsulates the virtual machine.
    /// It provides essential controls for starting, stopping, and configuring the VM, as well as handling tasks like
    /// installation and graphical output. This property allows the conforming type to control the VM directly.
    var vzVirtualMachine: VZVirtualMachine { get }
    
    /// A reference to the state manager responsible for tracking the VM’s execution state.
    ///
    /// `stateCoordinator` is an instance of `StateCoordinator` that manages access to and updates the VM’s execution state.
    /// This property provides centralized control over state management, helping ensure that the VM’s state is safely
    /// updated and accessible to observers, such as the UI.
    var stateCoordinator: StateCoordinator { get }
    
    // MARK: - Methods
    
    /// Starts a transition on the virtual machine and updates the shared state accordingly.
    ///
    /// This method provides a standard way to interact with the `VZVirtualMachine` instance by sending specific commands,
    /// such as starting, stopping, or pausing the VM. The `performTransition(_:)` method should handle updating the
    /// `stateCoordinator` to reflect any changes to the VM’s state. In the event of an error, the state should be
    /// safely reset before the error is propagated.
    ///
    /// - Parameter action: A `ExecutableAction` instance that describes the operation to be performed.
    /// - Throws: An error if the command execution fails, with the state reset as needed before propagation.
    func performTransition(executing: ExecutableAction) async throws
    
    /// Attaches a removable USB disk to the virtual machine using a specified disk image.
    ///
    /// This method allows for adding a USB mass storage device to the virtual machine, leveraging the existing
    /// USB controllers. The specified disk image is used to create the device, which is then attached to the VM.
    /// The returned `UUID` can be used to manage the device, such as detaching it later.
    ///
    /// - Parameter url: A `URL` pointing to the disk image file to be attached. The file can be in a read-only
    ///   or writable configuration, depending on implementation details.
    /// - Returns: A `UUID` uniquely identifying the attached USB device.
    /// - Throws: An error if the attachment fails, such as if the virtual machine does not support XHCI USB
    ///   controllers. Possibly other errors related to device creation or attachment.
    @available(macOS 15.0, *)
    func attachRemovableUSBDisk(usingImageAt url: URL) async throws -> UUID

    /// Detaches a previously attached removable USB disk from the virtual machine.
    ///
    /// This method removes a USB mass storage device from the virtual machine using the provided `UUID`.
    /// The identifier must match a device previously attached using the `attachRemovableUSBDisk(usingImageAt:)` method.
    /// If the specified device is not found, an error is thrown.
    ///
    /// - Parameter id: The `UUID` identifying the USB device to be detached. This value should correspond to
    ///   a device previously attached to the VM.
    /// - Throws: Should throw an error if the detachment fails, such as iif the virtual machine does not support XHCI USB controllers,
    ///   or the supplied id doesn't match any device that is currently attached to the VM. Possibly also other errors related to the detachment process.
    @available(macOS 15.0, *)
    func detachRemovableUSBDisk(identifiedBy id: UUID) async throws
}
