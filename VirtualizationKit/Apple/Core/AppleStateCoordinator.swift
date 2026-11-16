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

import Observation

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
    
    /// Broadcasts the execution state. Private, so that only this coordinator can change it.
    ///
    /// Although declared as `nonisolated`, values are only ever sent from the main actor,
    /// ensuring thread safety in SwiftUI or other UI-related components.
    @ObservationIgnored
    private nonisolated let subject = CurrentValueSubject<ExecutionState, Never>(.stopped)

    /// A Combine publisher of the execution state: the current state on subscription, then every change.
    public nonisolated var statePublisher: AnyPublisher<ExecutionState, Never> {
        subject.eraseToAnyPublisher()
    }
    
    /// The current execution state of the virtual machine.
    ///
    /// This property reflects the active `ExecutionState` at any given time. It is marked
    /// `private(set)` to restrict external modifications but remains accessible for observers
    /// or UI components. Every change is also broadcast through `statePublisher`; see `publish(_:)`.
    @ObservationTracked
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
    /// that state through `statePublisher`. This pattern helps reflect installation or setup progress in real time.
    ///
    /// - Parameter publisher: A `Publisher` emitting progress values (`Double`), often from a `Progress` object.
    func subscribe<T: Publisher>(_ publisher: T) where T.Output == Double,
                                                       T.Failure == Never {
        cancellables[.macOSInstaller] = publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.publish(.installing(progress: progress))
            }
    }

    /// Registers a `Publisher` emitting `VZVirtualMachine.State`, mapping those states to an `ExecutionState`.
    ///
    /// Whenever a new state is emitted, it is converted to the corresponding `ExecutionState`. If the transition is valid,
    /// the `executionState` is updated and the new state is broadcast through `statePublisher`. This approach cleanly
    /// integrates VirtualizationKit state changes into the coordinator's observable model.
    ///
    /// - Parameter publisher: A `Publisher` that emits `VZVirtualMachine.State` values.
    func subscribe<T: Publisher>(_ publisher: T) where T.Output == VZVirtualMachine.State,
                                                       T.Failure == Never {
       cancellables[.vzVirtualMachine] = publisher
           .receive(on: DispatchQueue.main)
           .sink { [weak self] newVZState in
               guard let newExecutionState = ExecutionState(newVZState)
               else { return }

               // While macOS is being installed, the installer drives the machine through states of
               // its own. Only the final stop is let through; the progress stays on screen until then.
               if case .installing = self?.executionState, newExecutionState != .stopped { return }

               // The delegate may have reported the specific error first; the generic one must not replace it.
               if case .error = newExecutionState, case .error = self?.executionState { return }

               self?.publish(newExecutionState)
           }
    }
    
    /// Registers a `Publisher` emitting `Error` values, converting those errors into an `.error` execution state.
    ///
    /// Whenever an error is received, the `executionState` is updated to `.error(error:)` and broadcast through
    /// `statePublisher`. This enables centralized handling and observation of errors that may occur during VM operations.
    ///
    /// An error received here always replaces the current one: it is specific, while the error of an `.error` state
    /// reported by Virtualization.framework itself is the generic `VZKitError.internalVirtualizationError`.
    ///
    /// - Parameter publisher: A `Publisher` that emits `Error` values, representing VM or system-level issues.
    func subscribe<T: Publisher>(_ publisher: T) where T.Output == Error,
                                                       T.Failure == Never {
        cancellables[.errorDelegate] = publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self]  error in
                self?.publish(.error(error: error))
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
        
        if shouldReset { resetExecutionState() }
    }
    
    /// Re-aligns the coordinator with the hypervisor after a lifecycle request failed.
    ///
    /// A request can fail without the observed framework state reaching the coordinator in a form that
    /// ends the transition it started (for example a start that is rejected), which would leave the
    /// coordinator in a transitional state, and the machine could never be started again. The caller
    /// reads the framework state on the machine's queue and hands it over.
    ///
    /// A specific error already published by the delegate is kept; otherwise a framework `.error` is
    /// reported with the generic `VZKitError.internalVirtualizationError`.
    ///
    /// - Parameter vzState: The state reported by the hypervisor right after the failure.
    func reconcile(with vzState: VZVirtualMachine.State) {
        switch vzState {
        case .stopped:
            // An error published by the delegate carries more information than a bare stop.
            if case .error = executionState { return }
            if executionState != .stopped { resetExecutionState() }

        case .error:
            // Keep the specific error if the delegate published one; report the generic one otherwise.
            if case .error = executionState { return }
            if let error = ExecutionState(vzState) { publish(error) }

        default:
            guard let newExecutionState = ExecutionState(vzState),
                  newExecutionState != executionState else { return }

            publish(newExecutionState)
        }
    }

    /// Resets the virtual machine's execution state to `.stopped` and broadcasts the new state.
    ///
    /// This method is typically called when an operation needs to be aborted mid-execution,
    /// when a fatal error prevents further progress, or when a clean slate is required
    /// between distinct VM lifecycles. It ensures that both the observable property and
    /// the Combine publisher (`statePublisher`) reflect the `.stopped` state, keeping all
    /// subscribers in sync.
    ///
    /// - Note: Use this method with caution. It does not perform any teardown of the
    ///   underlying `VZVirtualMachine`, so calling it while a VM is still running may
    ///   result in inconsistent state between the coordinator and the VM itself. Always
    ///   ensure the VM has been properly stopped before invoking this method.
    func resetExecutionState() {
        publish(.stopped)
    }

    /// Moves to a state and broadcasts it.
    ///
    /// The only place the state changes, so that `executionState` and `statePublisher` never disagree.
    ///
    /// - Parameter state: The new state.
    private func publish(_ state: ExecutionState) {
        self.executionState = state
        self.subject.send(state)
    }
}
