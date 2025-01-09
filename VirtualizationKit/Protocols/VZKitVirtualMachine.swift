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

/// The `VZKitVirtualMachine` protocol defines the requirements for implementing a virtual machine (VM) within this application.
/// This protocol specifies the essential properties and methods needed to manage and control a virtual machine, including
/// handling commands, accessing configuration information, managing state, and supporting delegation for event handling.
///
/// Conforming types must provide specific types for VM templates, state management, and delegates, enabling flexible
/// implementations that integrate seamlessly with the `Virtualization` framework.
public protocol VZKitVirtualMachine: Sendable {
    
    /// A type representing the possible commands that can be sent to the virtual machine.
    ///
    /// `CommandIterable` should be an `enum` conforming to `CaseIterable`, with cases for each command that
    /// the developer wishes to support in their VM implementation. For example, commands might include:
    /// `.start`, `.stop`, `.pause`, and `.resume`. The specific cases are left to the developer’s discretion
    /// to suit the application’s needs.
    associatedtype CommandIterable: CaseIterable
    
    /// A type representing the template data required to configure the virtual machine.
    ///
    /// `Template` must conform to `VZKitTemplate`, which provides the essential configuration details
    /// for initializing or managing a virtual machine, such as resource allocations and other setup parameters.
    associatedtype Template: VZKitTemplate
    
    /// A type representing the delegate responsible for handling virtual machine events.
    ///
    /// `DelegateType` must conform to `VZKitMachineDelegate` and is used to manage VM-specific events
    /// like state transitions, errors, and other lifecycle notifications. The delegate acts as an intermediary
    /// between the VM and other parts of the application that need to respond to VM events.
    associatedtype DelegateType: VZKitMachineDelegate
    
    /// A type representing the state manager responsible for tracking the virtual machine’s execution state.
    ///
    /// `StateManagerType` must conform to `VZKitMachineStateManager` and is responsible for holding and
    /// updating the VM’s state information. The state manager ensures that any state changes are safely managed,
    /// supporting UI updates and other components that depend on the VM’s current state.
    associatedtype StateManagerType: VZKitMachineStateManager
    
    /// The template data used to configure the virtual machine.
    ///
    /// `template` holds a copy of the data transfer object (DTO) required to initialize and manage the virtual machine.
    /// It provides configuration information, such as memory size, CPU count, and storage configuration.
    var template: Template { get }
    
    /// A reference to the VM’s delegate, responsible for handling events and notifications from the virtual machine.
    ///
    /// `delegate` is an instance conforming to `VZKitMachineDelegate` and is associated with the virtual machine.
    /// It listens for and processes events from the VM, facilitating communication between the VM and other parts
    /// of the application that need to respond to VM lifecycle events or state changes.
    var delegate: DelegateType { get }

    /// A reference to the `VZVirtualMachine` instance, providing core functionality for VM management.
    ///
    /// `vzVirtualMachine` is the main object from the `Virtualization` framework that encapsulates the virtual machine.
    /// It provides essential controls for starting, stopping, and configuring the VM, as well as handling tasks like
    /// installation and graphical output. This property allows the conforming type to control the VM directly.
    var vzVirtualMachine: VZVirtualMachine { get }
    
    /// A reference to the state manager responsible for tracking the VM’s execution state.
    ///
    /// `stateManager` is an instance of `StateManagerType` that manages access to and updates the VM’s execution state.
    /// This property provides centralized control over state management, helping ensure that the VM’s state is safely
    /// updated and accessible to observers, such as the UI.
    var stateManager: StateManagerType { get }
    
    /// Creates a new virtual machine instance based on the specified template.
    ///
    /// This static factory method returns a result containing either a new instance of the conforming type or an error
    /// if the creation process fails. By using `Result<Self, Error>`, this method provides a mechanism for handling
    /// errors that may occur during VM creation, allowing the caller to take action (e.g., showing an error message)
    /// if needed.
    ///
    /// - Parameter template: The data transfer object containing the configuration information for the VM.
    /// - Returns: A `VZKitResult<Template>` containing either a new virtual machine instance or an error.
    static func createMachine(_ template: Template) async -> VZKitResult<Template>
    
    /// Sends a command to the virtual machine and updates the shared state accordingly.
    ///
    /// This method provides a standard way to interact with the `VZVirtualMachine` instance by sending specific commands,
    /// such as starting, stopping, or pausing the VM. The `sendCommand(_:)` method should handle updating the
    /// `stateManager` to reflect any changes to the VM’s state. In the event of an error, the state should be
    /// safely reset before the error is propagated.
    ///
    /// - Important: This method is pinned to `@VZKitActor` to ensure serial execution of commands, which helps
    ///   maintain consistency and avoid race conditions when controlling the VM.
    ///
    /// - Parameter command: A `CommandIterable` case representing the command to be executed on the VM.
    /// - Throws: An error if the command execution fails, with the state reset as needed before propagation.
    @VZKitActor func sendCommand(_ command: CommandIterable) async throws
    
    /// Attaches a removable USB disk to the virtual machine using a specified disk image.
    ///
    /// This method allows for adding a USB mass storage device to the virtual machine, leveraging the existing
    /// USB controllers. The specified disk image is used to create the device, which is then attached to the VM.
    /// The returned `UUID` can be used to manage the device, such as detaching it later.
    ///
    /// - Important: This method is pinned to `@VZKitActor` to ensure serial execution of operations,
    ///   maintaining consistency and preventing race conditions during device attachment.
    ///
    /// - Parameter url: A `URL` pointing to the disk image file to be attached. The file can be in a read-only
    ///   or writable configuration, depending on implementation details.
    /// - Returns: A `UUID` uniquely identifying the attached USB device.
    /// - Throws: An error if the attachment fails, such as if the virtual machine does not support XHCI USB
    ///   controllers. Possibly other errors related to device creation or attachment.
    @available(macOS 15.0, *)
    @VZKitActor func attachRemovableUSBDisk(usingImageAt url: URL) async throws -> UUID

    /// Detaches a previously attached removable USB disk from the virtual machine.
    ///
    /// This method removes a USB mass storage device from the virtual machine using the provided `UUID`.
    /// The identifier must match a device previously attached using the `attachRemovableUSBDisk(usingImageAt:)` method.
    /// If the specified device is not found, an error is thrown.
    ///
    /// - Important: This method is pinned to `@VZKitActor` to ensure serial execution of operations,
    ///   maintaining consistency and avoiding race conditions during device detachment.
    ///
    /// - Parameter id: The `UUID` identifying the USB device to be detached. This value should correspond to
    ///   a device previously attached to the VM.
    /// - Throws: Should throw an error if the detachment fails, such as iif the virtual machine does not support XHCI USB controllers,
    ///   or the supplied id doesn't match any device that is currently attached to the VM. Possibly also other errors related to the detachment process.
    @available(macOS 15.0, *)
    @VZKitActor func detachRemovableUSBDisk(identifiedBy id: UUID) async throws
}
