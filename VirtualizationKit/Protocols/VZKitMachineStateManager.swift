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
//  VZKitMachineStateManager.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 09/11/24.
//

import Combine

import Virtualization
    
/// The `MachineStateManager` class is responsible for managing and tracking the execution state of a virtual machine
/// in an observable and thread-safe manner. By using the `@Observable` macro, this class allows SwiftUI views
/// or other observers to react to state changes automatically. The class is marked as `@MainActor`, ensuring that
/// all state updates occur on the main thread, making it safe for use in UI-bound contexts.
///
/// `MachineStateManager` provides functionality for tracking the current execution state, monitoring progress,
/// and supporting rollback functionality to a previous state.
///
/// - Important: This is pinned to @MainActor because everything should be used to update the UI
@MainActor public protocol VZKitMachineStateManager {
    
    associatedtype StateType: VZKitMachineState
    
    /// The current execution state of the virtual machine.
    ///
    /// The `wrapped` property represents the active `MachineState` of the virtual machine.
    /// It is marked as `private(set)` to restrict external modification, while still allowing
    /// observers to access the current state. This property updates whenever a new state is received,
    /// and the `StateManager` automatically notifies observers of any changes.
    var wrapped: StateType { get set }
    
    /// A value representing the current progress of the virtual machine operation.
    ///
    /// `progress` is a `Double` value that can be used to track the progress of operations like
    /// installation or restoration. It is marked `private(set)` to restrict external modifications
    /// while allowing read access. Changes to this property can be observed by SwiftUI views to update
    /// UI elements like progress bars.
    var progress: Double { get set }
    
    /// The previous execution state of the virtual machine, used for rollback purposes.
    ///
    /// `last` temporarily stores the prior state of the virtual machine. It is marked with
    /// `@ObservationIgnored` to prevent this property from triggering any observer notifications
    /// since it’s only used internally to manage rollbacks.
    var last: StateType? { get set }
    
    /// A set of Combine cancellables used to store subscriptions.
    ///
    /// `cancellables` holds the Combine subscriptions associated with the state updates. It is marked
    /// with `@ObservationIgnored` to prevent notifications from being triggered when changes occur.
    var cancellables: Set<AnyCancellable> { get set }
    
    /// Updates the current state to a new execution state.
    ///
    /// The `update(with:)` method changes the `wrapped` property to the provided `new` state
    /// and stores the previous state in `last` to allow for potential rollback.
    ///
    /// - Parameter new: The new `MachineState` to update to.
    func update(with new: StateType)
    
    /// Rolls back to the previous execution state.
    ///
    /// The `rollback()` method reverts `wrapped` to the `last` saved state, or defaults to `.stopped`
    /// if there is no previous state. This provides a simple way to undo recent state changes.
    func rollback()
    
    /// Registers an external `Progress` instance to update the progress property of the virtual machine.
    ///
    /// The `registerProgress(_:)` method should subscrive to a `Progress` object’s `fractionCompleted` property,
    /// to allow the progress of long-running operations to be automatically reflected in the `progress` property,
    /// which observers can use to update UI elements like progress bars.
    ///
    /// - Parameter progress: A `Progress` instance representing the operation whose progress should be tracked.
    func registerProgress(_ progress: Progress)
}
