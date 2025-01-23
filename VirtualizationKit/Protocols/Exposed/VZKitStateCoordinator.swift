//
//  VZKitStateCoordinator.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 09/11/24.
//

import Combine

import Virtualization

/// A protocol for managing and observing the execution state and progress of a virtual machine.
///
/// The `VZKitStateCoordinator` protocol defines a standard interface for coordinating the state
/// and progress of virtual machine operations in a thread-safe and observable manner. This protocol
/// is designed to be used in environments where state updates must occur on the main thread, such as
/// UI-bound applications leveraging SwiftUI or Combine.
///
/// Conforming types must implement functionality to:
/// - Track the current execution state (`currentState`) of the virtual machine.
/// - Report progress of ongoing operations (`progress`).
/// - Allow state transitions via the `update(with:)` method.
/// - Register publishers for observing state or progress changes.
///
/// ## Concurrency
/// All conforming types must operate within the `@MainActor` context to ensure thread safety
/// and UI compatibility.
///
/// - Note: This protocol is pinned to `@MainActor` to ensure safe usage in UI-related contexts.
@MainActor public protocol VZKitStateCoordinator {
    
    /// The current execution state of the virtual machine.
    ///
    /// The `currentState` property represents the active `ExecutionState` of the virtual machine.
    /// This property should be updated whenever a new state is received.
    var currentState: ExecutionState { get }
    
    /// Registers a generic `Publisher` and defines a sink closure to handle its output.
    ///
    /// This method subscribes to a `Publisher` and ensures that updates are received on the main thread.
    /// The provided sink closure is executed with each emitted value from the publisher.
    /// The subscriptions should be used to update the state of the instance that uses this interface
    ///
    /// - Parameters:
    ///   - publisher: A `Publisher` instance that emits values to be handled.
    ///   - sink: A closure that processes the emitted values from the publisher.
    func registerPublisher<T: Publisher>(_ publisher: T, sink: @escaping (T.Output) -> Void) where T.Failure == Never
}
