//
//  Copyright 2025 Giuseppe Rocco
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
//  -----------------------------------------------------------------------
//
//  AppleStateCoordinator.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 08/11/24.
//

import Virtualization

@unsafe @preconcurrency import Combine
    
/// The `AppleStateCoordinator` class serves as a main-actor-isolated manager for a virtual machine's execution state.
/// It leverages Combine to broadcast state changes and provides methods to register external publishers for seamless
/// integration with other asynchronous or lower-level APIs. Since this class is marked with `@MainActor`, all state
/// mutations and observer callbacks occur on the main thread, making it safe for UI-bound contexts.
@MainActor @Observable
public final class AppleStateCoordinator: StateCoordinator {
    
    /// Identifies the specific source or category of a Combine subscription.
    ///
    /// This enumeration is used as a key in the `cancellables` dictionary to ensure that different
    /// types of publishers (e.g., VM state, installation progress, or error delegates) can be managed
    /// independently without overwriting each other.
    enum CancellableKind: Int {
        /// Subscription for the core virtual machine state updates (`VZVirtualMachine.State`).
        case vzVirtualMachine
        /// Subscription for macOS installation progress updates.
        case macOSInstaller
        /// Subscription for error events originating from delegates or system-level observers.
        case errorDelegate
    }
    
    /// A Combine subject that broadcasts updates to the virtual machine's execution state.
    ///
    /// Although declared as `nonisolated`, updates originate from the main actor,
    /// ensuring thread safety in SwiftUI or other UI-related components.
    @ObservationIgnored
    nonisolated public let stateSubject: PassthroughSubject<ExecutionState, Never> = .init()
    
    /// The current execution state of the virtual machine.
    ///
    /// This property reflects the active `ExecutionState` at any given time. It is marked
    /// `private(set)` to restrict external modifications but remains accessible for observers
    /// or UI components. State changes automatically trigger broadcasts to `stateSubject`.
    public private(set) var executionState: ExecutionState = .stopped
    
    /// A dictionary of Combine cancellables indexed by `CancellableKind`.
    ///
    /// Storing cancellables by kind allows for fine-grained control over the lifecycle of each subscription,
    /// enabling the removal or replacement of specific observers without affecting others.
    @ObservationIgnored
    private var cancellables: [CancellableKind: AnyCancellable] = [:]
    
    /// Registers a `Publisher` emitting `Double` values, typically representing progress updates.
    ///
    /// Each new `Double` output updates the `executionState` to `.installing(progress:)` and broadcasts
    /// that state through `stateSubject`. This pattern helps reflect installation or setup progress in real time.
    ///
    /// - Parameter publisher: A `Publisher` emitting progress values (`Double`), often from a `Progress` object.
    func subscribe<T: Publisher>(_ publisher: T) where T.Output == Double,
                                                       T.Failure == Never {
        cancellables[.macOSInstaller] = publisher
            .receive(on: RunLoop.main)
            .sink { [weak self] progress in
                self?.executionState = .installing(progress: progress)
                self?.stateSubject.send(.installing(progress: progress))
            }
    }

    /// Registers a `Publisher` emitting `VZVirtualMachine.State`, mapping those states to an `ExecutionState`.
    ///
    /// Whenever a new state is emitted, it is converted to the corresponding `ExecutionState`. If the transition is valid,
    /// the `executionState` is updated and the new state is broadcast through `stateSubject`. This approach cleanly
    /// integrates VirtualizationKit state changes into the coordinator's observable model.
    ///
    /// - Parameter publisher: A `Publisher` that emits `VZVirtualMachine.State` values.
    func subscribe<T: Publisher>(_ publisher: T) where T.Output == VZVirtualMachine.State,
                                                       T.Failure == Never {
       cancellables[.vzVirtualMachine] = publisher
           .receive(on: RunLoop.main)
           .sink { [weak self] newVZState in
               guard let newExecutionState = ExecutionState(newVZState)
               else { return }
           
               // Prevent transitioning from .stopped to anything else if rawValue == 10
               guard self?.executionState.rawValue != 10 ||
                     newExecutionState == .stopped else { return }
           
               self?.executionState = newExecutionState
               self?.stateSubject.send(newExecutionState)
           }
    }
    
    /// Registers a `Publisher` emitting `Error` values, converting those errors into an `.error` execution state.
    ///
    /// Whenever an error is received, the `executionState` is updated to `.error(error:)` and broadcast through
    /// `stateSubject`. This enables centralized handling and observation of errors that may occur during VM operations.
    ///
    /// - Parameter publisher: A `Publisher` that emits `Error` values, representing VM or system-level issues.
    func subscribe<T: Publisher>(_ publisher: T) where T.Output == Error,
                                                       T.Failure == Never {
        cancellables[.errorDelegate] = publisher
            .receive(on: RunLoop.main)
            .sink { [weak self]  error in
                self?.executionState = .error(error: error)
                self?.stateSubject.send(.error(error: error))
            }
    }
    
    /// Cancels and removes a specific subscription based on its kind, optionally resetting the execution state.
    ///
    /// This method allows for manual cleanup of resources associated with a publisher. If an installation is aborted
    /// or a transient error listener is no longer needed, this ensures that no further updates are processed for that kind.
    ///
    /// - Parameters:
    ///   - kind: The `CancellableKind` of the subscription to erase.
    ///   - shouldReset: A Boolean flag indicating whether the `executionState` should be reset to `.stopped`
    ///     after the subscription is cancelled. Defaults to `false`.
    func eraseSubscription(for kind: CancellableKind, shouldReset: Bool = false) {
        guard let cancellable = cancellables[kind]
        else { return }
        
        cancellable.cancel()
        cancellables.removeValue(forKey: kind)
        
        if shouldReset {
            self.executionState = .stopped
            self.stateSubject.send(.stopped)
        }
    }
}
