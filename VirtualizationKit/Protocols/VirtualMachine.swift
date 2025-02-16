//
//  VirtualMachine.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 14/05/24.
//

import Combine

import Virtualization

/// A protocol defining the core requirements for a templated virtual machine.
///
/// The `VirtualMachine` protocol offers a flexible contract that can be implemented by various
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
/// struct MyCustomVM: VirtualMachine {
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
public protocol VirtualMachine: Sendable {
    
    // MARK: - Associated Types
    
    /// Represents a high-level action that can be executed on the virtual machine.
    ///
    /// Common examples may include `.start`, `.stop`, or `.pause`. The actual implementation
    /// is backend-specific and determined by each conforming type.
    associatedtype Action: ExecutableAction
    
    /// Defines the template data required to configure the virtual machine.
    ///
    /// Conforming types must provide a struct or class implementing `TransferableTemplate` to encapsulate
    /// essential configuration details (e.g., CPU count, memory allocation, storage parameters).
    associatedtype Template: TransferableTemplate
    
    /// Manages and broadcasts the execution state of the virtual machine.
    ///
    /// `Coordinator` is responsible for tracking state changes such as transitioning from
    /// "running" to "stopped," and notifying observers (e.g., UI elements). Conforming types must
    /// properly update and utilize this coordinator in their implementation.
    associatedtype Coordinator: StateCoordinator
    
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
    var stateCoordinator: Coordinator { get }
    
    // MARK: - Methods
    
    /// Executes a virtual machine action, potentially transitioning the machine to a new state.
    ///
    /// Conforming types should implement backend-specific logic to handle the given `Action`.
    /// For instance, `.start` might trigger a boot sequence, while `.stop` could gracefully terminate
    /// the VM. Errors should be caught and propagated as needed, with the `stateCoordinator` updated
    /// to reflect any final state or error conditions.
    ///
    /// - Parameter action: The high-level action that the VM needs to perform.
    /// - Throws: An error if the command execution fails. Conforming implementations must ensure that
    ///           the state is updated or rolled back as appropriate before propagating the error.
    func execute(action: Action) async throws
    
    /// Initializes a new virtual machine instance using the specified configuration template.
    ///
    /// Conforming types must implement any backend-specific logic needed to transform the given
    /// `Template` into a functioning virtual machine. This could involve preparing hardware
    /// emulation settings, allocating resources, or validating configuration parameters.
    /// If the initialization process encounters issues—such as incompatible template data
    /// or resource limitations—an error should be thrown.
    ///
    /// - Parameter template: An instance conforming to `TransferableTemplate`, providing the configuration
    ///   details required to set up the virtual machine.
    /// - Throws: An error if the virtual machine cannot be properly initialized from the provided template.
    init(template: Template) async throws
}


// MARK: - General Extension

/// Provides a convenience property to access the virtual machine's state publisher.
///
/// This extension of `VirtualMachine` exposes a computed property `stateSubject`
/// that directly retrieves the state coordinator’s publisher. This allows client code to subscribe
/// to execution state updates without having to access the state coordinator directly.
public extension VirtualMachine {
    
    /// A Combine publisher that emits updates to the virtual machine's execution state.
    ///
    /// This property forwards to the underlying `stateCoordinator.stateSubject`, enabling observers
    /// (e.g., view models or UI components) to react to state changes as they occur.
    var stateSubject: PassthroughSubject<ExecutionState, Never> {
        stateCoordinator.stateSubject
    }
}

// MARK: - MainActor Extension

/// Provides additional execution state properties for a `VirtualMachine` operating on the main actor.
///
/// This extension is marked with `@MainActor` to ensure that all state-related computations and access
/// occur on the main thread, which is critical for UI updates. It adds computed properties that expose:
///
/// - The current execution state.
/// - Boolean flags indicating whether the virtual machine is in a state where it can be started, stopped,
///   paused, or resumed.
///
/// These properties abstract the raw state values, offering a more expressive API for controlling the
/// virtual machine based on its execution state.
@MainActor
public extension VirtualMachine {
    
    /// The current execution state of the virtual machine.
    ///
    /// This property forwards to the `stateCoordinator.executionState`, reflecting the latest known state.
    var executionState: ExecutionState {
        stateCoordinator.executionState
    }
    
    /// Indicates whether the virtual machine can be started.
    ///
    /// Returns `true` if the current execution state's raw value is either 0 or 3.
    var canStart: Bool {
        [0, 3].contains(stateCoordinator.executionState.rawValue)
    }
    
    /// Indicates whether the virtual machine can be stopped.
    ///
    /// Returns `true` if the current execution state's raw value is either 1 or 2.
    var canStop: Bool {
        [1, 2].contains(stateCoordinator.executionState.rawValue)
    }
    
    /// Indicates whether the virtual machine can be paused.
    ///
    /// Returns `true` if the current execution state is `.running`.
    var canPause: Bool {
        stateCoordinator.executionState == .running
    }
    
    /// Indicates whether the virtual machine can be resumed.
    ///
    /// Returns `true` if the current execution state is `.paused`.
    var canResume: Bool {
        stateCoordinator.executionState == .paused
    }
}
