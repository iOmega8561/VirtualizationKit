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
//  VirtualMachine+State.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 08/11/24.
//

@preconcurrency import Combine

import Virtualization
    
/// The `MachineStateManager` class is responsible for managing and tracking the execution state of a virtual machine
/// in an observable and thread-safe manner. By using the `@Observable` macro, this class allows SwiftUI views
/// or other observers to react to state changes automatically. The class is marked as `@MainActor`, ensuring that
/// all state updates occur on the main thread, making it safe for use in UI-bound contexts.
///
/// `MachineStateManager` provides functionality for tracking the current execution state, monitoring progress,
/// and supporting rollback functionality to a previous state.
@Observable public final class MachineStateManager: VZKitMachineStateManager {
    
    /// The current execution state of the virtual machine.
    ///
    /// The `currentState` property represents the active `MachineState` of the virtual machine.
    /// It is marked as `private(set)` to restrict external modification, while still allowing
    /// observers to access the current state. This property updates whenever a new state is received,
    /// and the `StateManager` automatically notifies observers of any changes.
    public private(set) var currentState: MachineState = .stopped
    
    /// A value representing the current progress of the virtual machine operation.
    ///
    /// `progress` is a `Double` value that can be used to track the progress of operations like
    /// installation or restoration. It is marked `private(set)` to restrict external modifications
    /// while allowing read access. Changes to this property can be observed by SwiftUI views to update
    /// UI elements like progress bars.
    public private(set) var progress: Double = 0
    
    /// The previous execution state of the virtual machine, used for rollback purposes.
    ///
    /// `lastState` temporarily stores the prior state of the virtual machine. It is marked with
    /// `@ObservationIgnored` to prevent this property from triggering any observer notifications
    /// since it’s only used internally to manage rollbacks.
    @ObservationIgnored public private(set) var lastState: MachineState?
    
    /// A set of Combine cancellables used to store subscriptions.
    ///
    /// `cancellables` holds the Combine subscriptions associated with the state updates. It is marked
    /// with `@ObservationIgnored` to prevent notifications from being triggered when changes occur.
    @ObservationIgnored private var cancellables: Set<AnyCancellable>! = .init()
    
    /// Updates the current state to a new execution state.
    ///
    /// The `update(with:)` method changes the `wrapped` property to the provided `new` state
    /// and stores the previous state in `last` to allow for potential rollback.
    ///
    /// - Parameter new: The new `MachineState` to update to.
    public func update(with newState: MachineState) {
        lastState = currentState
        currentState = newState
    }
    
    /// Rolls back to the previous execution state.
    ///
    /// The `rollback()` method reverts `wrapped` to the `last` saved state, or defaults to `.stopped`
    /// if there is no previous state. This provides a simple way to undo recent state changes.
    public func rollback() {
        currentState = lastState ?? .stopped
    }
        
    /// Registers an external `Progress` instance to update the progress property of the virtual machine.
    ///
    /// The `registerProgress(_:)` method subscribes to a `Progress` object’s `fractionCompleted` property.
    /// This allows the progress of long-running operations to be automatically reflected in the `progress` property,
    /// which observers can use to update UI elements like progress bars.
    ///
    /// - Parameter progress: A `Progress` instance representing the operation whose progress should be tracked.
    public func registerProgress(_ progress: Progress) {
        progress
            .publisher(for: \.fractionCompleted)
            .sink { [weak self] progress in
                self?.progress = progress
            }
            .store(in: &cancellables)
    }
    
    /// Initializes a new `MachineStateManager` instance and binds it to a `Delegate`.
    ///
    /// - Parameter delegate: The `Delegate` instance responsible for broadcasting state changes.
    ///   The `MachineStateManager` subscribes to the delegate’s `statePublisher` and automatically updates
    ///   `wrapped` whenever a new state is published.
    init(_ delegate: MachineDelegate) {
        
        delegate.statePublisher
            .sink { [weak self] state in
                self?.currentState = state
            }
            .store(in: &cancellables)
    }
    
    /// Explicitly sets `cancellables` to `nil` to release any subscriptions in this object.
    ///
    /// In Combine, cancelling a subscription removes the closure's reference to `self`, breaking potential retain cycles.
    /// Setting `cancellables` to `nil` ensures that all stored subscriptions are released immediately,
    /// allowing `deinit` to free up memory more predictably and prevent lingering references.
    ///
    /// This explicit release can be beneficial for:
    /// - Ensuring that asynchronous Combine pipelines do not retain `self` longer than expected.
    /// - Preventing certain Combine operators (like `sink`) from delaying deallocation.
    /// - Helping tools like Instruments confirm that no lingering retain cycles exist.
    deinit { cancellables = nil }
}
