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
//  ObservableCoordinator.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 08/11/24.
//

@preconcurrency import Combine

import Virtualization
    
/// The `ObservableCoordinator` class is responsible for managing and tracking the execution state of a virtual machine
/// in an observable and thread-safe manner. By using the `@Observable` macro, this class allows SwiftUI views
/// or other observers to react to state changes automatically. The class is marked as `@MainActor`, ensuring that
/// all state updates occur on the main thread, making it safe for use in UI-bound contexts.
///
/// `ObservableCoordinator` provides functionality for tracking the current execution state, monitoring progress,
/// and supporting rollback functionality to a previous state.
@Observable public final class ObservableCoordinator: VZKitStateCoordinator {
    
    /// The current execution state of the virtual machine.
    ///
    /// The `currentState` property represents the active `ExecutionState` of the virtual machine.
    /// It is marked as `private(set)` to restrict external modification, while still allowing
    /// observers to access the current state. This property updates whenever a new state is received,
    /// and the `stateCoordinator` automatically notifies observers of any changes.
    public private(set) var currentState: ExecutionState = .stopped
    
    /// A set of Combine cancellables used to store subscriptions.
    ///
    /// `cancellables` holds the Combine subscriptions associated with the state updates.
    private var cancellables: Set<AnyCancellable> = .init()
    
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
            self?.currentState = .installing(progress: progress)
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
            guard let state = ExecutionState(state) else { return }
            self?.currentState = state
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
    func registerPublisher<T: Publisher>(_ publisher: T) where T.Output == Error, T.Failure == Never {
        registerPublisher(publisher) { [weak self] error in
            self?.currentState = .error(error: error)
        }
    }
}
