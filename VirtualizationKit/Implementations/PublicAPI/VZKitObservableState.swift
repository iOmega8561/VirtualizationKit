//
//  VZKitObservableState.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 08/11/24.
//

@preconcurrency import Combine

import Virtualization
    
/// The `VZKitObservableState` class is responsible for managing and tracking the execution state of a virtual machine
/// in an observable and thread-safe manner. By using the `@Observable` macro, this class allows SwiftUI views
/// or other observers to react to state changes automatically. The class is marked as `@MainActor`, ensuring that
/// all state updates occur on the main thread, making it safe for use in UI-bound contexts.
///
/// `VZKitObservableState` provides functionality for tracking the current execution state, monitoring progress,
/// and supporting rollback functionality to a previous state.
@Observable public final class VZKitObservableState: VZKitStateCoordinator {
    
    /// The current execution state of the virtual machine.
    ///
    /// The `currentState` property represents the active `VZVirtualMachine.State` of the virtual machine.
    /// It is marked as `private(set)` to restrict external modification, while still allowing
    /// observers to access the current state. This property updates whenever a new state is received,
    /// and the `StateManager` automatically notifies observers of any changes.
    public private(set) var currentState: VZVirtualMachine.State = .stopped
    
    /// A value representing the current progress of the virtual machine operation.
    ///
    /// `progress` is a `Double` value that can be used to track the progress of operations like
    /// installation or restoration. It is marked `private(set)` to restrict external modifications
    /// while allowing read access. Changes to this property can be observed by SwiftUI views to update
    /// UI elements like progress bars.
    public private(set) var progress: Double = 0
    
    /// The previous execution state of the virtual machine, used for rollback purposes.
    ///
    /// `lastState` temporarily stores the prior state of the virtual machine.
    private var lastState: VZVirtualMachine.State?
    
    /// A set of Combine cancellables used to store subscriptions.
    ///
    /// `cancellables` holds the Combine subscriptions associated with the state updates.
    private var cancellables: Set<AnyCancellable> = .init()
    
    /// Updates the current state to a new execution state.
    ///
    /// The `update(with:)` method changes the `wrapped` property to the provided `new` state
    /// and stores the previous state in `last` to allow for potential rollback.
    ///
    /// - Parameter new: The new `VZVirtualMachine.State` to update to.
    public func update(with newState: VZVirtualMachine.State) {
        lastState = currentState; currentState = newState
    }
    
    /// Registers a generic `Publisher` and defines a sink closure to handle its output.
    ///
    /// This method subscribes to a `Publisher` and ensures that updates are received on the main thread.
    /// The provided sink closure is executed with each emitted value from the publisher.
    /// The subscriptions are stored by the instance and their lifecycle is managed
    ///
    /// - Parameters:
    ///   - publisher: A `Publisher` instance that emits values to be handled.
    ///   - sink: A closure that processes the emitted values from the publisher.
    public func registerPublisher<T: Publisher>(_ publisher: T, sink: @escaping (T.Output) -> Void) where T.Failure == Never {
        publisher
            .receive(on: RunLoop.main)
            .sink(receiveValue: sink)
            .store(in: &cancellables)
    }
    
    /// Rolls back to the previous execution state.
    ///
    /// The `rollback()` method reverts `wrapped` to the `last` saved state, or defaults to `.stopped`
    /// if there is no previous state. This provides a simple way to undo recent state changes.
     func rollback() { currentState = lastState ?? .stopped }
    
    /// Registers an external `Publisher` conforming instance to update the progress property of the virtual machine.
    ///
    /// The `registerPublisher(_:)` method subscribes to a `Progress` publisher for `fractionCompleted` property.
    /// This allows the progress of long-running operations to be automatically reflected in the `progress` property,
    /// which observers can use to update UI elements like progress bars.
    ///
    /// - Parameter publisher: A `Publisher`  conforming instance acquired using `.publisher(for: \.fractionCompleted)`
    /// representing the operation whose progress should be tracked.
    func registerPublisher<T: Publisher>(_ publisher: T) where T.Output == Double,
                                                               T.Failure == Never {
        registerPublisher(publisher) { [weak self] progress in
            self?.progress = progress
        }
    }

    /// Registers an external `Publisher` conforming instance to update the currentState property of the virtual machine.
    ///
    /// The `registerPublisher(_:)` method subscribes to a `Progress` publisher to update the `currentState` property
    /// This allows the progress of long-running operations to be automatically reflected in the `progress` property,
    /// which observers can use to update UI elements like progress bars.
    ///
    /// - Parameter publisher: A `Publisher`  conforming instance acquired using `.publisher(for: \.fractionCompleted)`
    /// representing the operation whose progress should be tracked.
    func registerPublisher<T: Publisher>(_ publisher: T) where T.Output == VZVirtualMachine.State,
                                                               T.Failure == Never {
        registerPublisher(publisher) { [weak self] state in
            self?.update(with: state)
        }
    }
}
