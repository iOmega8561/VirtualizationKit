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

/// A protocol defining the core requirements for a templated virtual machine.
///
/// The `VZKitVirtualMachine` protocol offers a flexible contract that can be implemented by various
/// virtualization backends (e.g., Apple Virtualization, QEMU). It prescribes a set of associated
/// types for managing actions, configuration templates, and execution state. Conforming types
/// should be `Sendable`, ensuring safe interaction in concurrent environments.
///
/// ## Key Responsibilities
/// - **Action Dispatch**: Implement a mechanism to handle and execute high-level VM actions (e.g., start, stop).
/// - **Configuration**: Provide a template object describing how the VM is set up (e.g., memory, disk, CPU).
/// - **State Management**: Expose a state coordinator that observes and broadcasts execution state changes.
///
/// ## Concurrency
/// Since conforming types are `Sendable`, all operations, including state mutations, must be designed
/// to work correctly with Swift concurrency. The `execute(action:)` method is asynchronous, allowing
/// smooth integration within structured concurrency or other async/await patterns.
///
/// ## Example Usage
/// ```swift
/// struct MyCustomVM: VZKitVirtualMachine {
///     typealias ExecutableAction = MyVMAction
///     typealias Template = MyVMTemplate
///     typealias StateCoordinator = MyStateCoordinator
///
///     var template: MyVMTemplate
///     var stateCoordinator: MyStateCoordinator
///
///     func execute(action: MyVMAction) async throws {
///         // Handle VM transitions, update state, manage resources, etc.
///     }
/// }
/// ```
///
/// By separating VM operations into discrete actions, configuration templates, and a dedicated state
/// coordinator, this protocol ensures a clean structure that can be adapted to diverse virtualization
/// solutions.
public protocol VZKitVirtualMachine: Sendable {
    
    // MARK: - Associated Types
    
    /// Represents a high-level action that can be executed on the virtual machine.
    ///
    /// Common examples may include `.start`, `.stop`, or `.pause`. The actual implementation
    /// is backend-specific and determined by each conforming type.
    associatedtype ExecutableAction: Sendable
    
    /// Defines the template data required to configure the virtual machine.
    ///
    /// Conforming types must provide a struct or class implementing `VZKitTemplate` to encapsulate
    /// essential configuration details (e.g., CPU count, memory allocation, storage parameters).
    associatedtype Template: VZKitTemplate
    
    /// Manages and broadcasts the execution state of the virtual machine.
    ///
    /// `StateCoordinator` is responsible for tracking state changes such as transitioning from
    /// "running" to "stopped," and notifying observers (e.g., UI elements). Conforming types must
    /// properly update and utilize this coordinator in their implementation.
    associatedtype StateCoordinator: VZKitStateCoordinator
    
    // MARK: - Properties
    
    /// The template object providing configuration details for the virtual machine.
    ///
    /// This property supplies all necessary data—like memory, storage, and CPU configurations—to
    /// initialize and manage the VM lifecycle. Conforming implementations should ensure the template
    /// remains consistent with any backend-specific requirements.
    var template: Template { get }
    
    /// The state manager responsible for tracking the VM's execution state.
    ///
    /// Conforming implementations should keep the `stateCoordinator` in sync with any state
    /// transitions triggered by `execute(action:)` or other internal operations. Observers
    /// can listen for state changes through the coordinator's `stateSubject` or similar mechanism.
    var stateCoordinator: StateCoordinator { get }
    
    // MARK: - Methods
    
    /// Executes a virtual machine action, potentially transitioning the machine to a new state.
    ///
    /// Conforming types should implement backend-specific logic to handle the given `ExecutableAction`.
    /// For instance, `.start` might trigger a boot sequence, while `.stop` could gracefully terminate
    /// the VM. Errors should be caught and propagated as needed, with the `stateCoordinator` updated
    /// to reflect any final state or error conditions.
    ///
    /// - Parameter action: The high-level action that the VM needs to perform.
    /// - Throws: An error if the command execution fails. Conforming implementations must ensure that
    ///           the state is updated or rolled back as appropriate before propagating the error.
    func execute(action: ExecutableAction) async throws
    
    /// Initializes a new virtual machine instance using the specified configuration template.
    ///
    /// Conforming types must implement any backend-specific logic needed to transform the given
    /// `Template` into a functioning virtual machine. This could involve preparing hardware
    /// emulation settings, allocating resources, or validating configuration parameters.
    /// If the initialization process encounters issues—such as incompatible template data
    /// or resource limitations—an error should be thrown.
    ///
    /// - Parameter template: An instance conforming to `VZKitTemplate`, providing the configuration
    ///   details required to set up the virtual machine.
    /// - Throws: An error if the virtual machine cannot be properly initialized from the provided template.
    init(template: Template) async throws
}
