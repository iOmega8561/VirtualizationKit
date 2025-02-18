//
//  AppleStateCoordinator.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 08/11/24.
//

@preconcurrency import Combine

import Virtualization
    
/// The `AppleStateCoordinator` class serves as a main-actor-isolated manager for a virtual machine's execution state.
/// It leverages Combine to broadcast state changes and provides methods to register external publishers for seamless
/// integration with other asynchronous or lower-level APIs. Since this class is marked with `@MainActor`, all state
/// mutations and observer callbacks occur on the main thread, making it safe for UI-bound contexts.
@MainActor @Observable
public final class AppleStateCoordinator: StateCoordinator {
    
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
    
    /// A collection of Combine cancellables used for managing the lifecycle of subscriptions.
    ///
    /// All subscriptions created through the `registerPublisher(_:)` variants are stored here to
    /// ensure they remain active for the lifetime of this coordinator.
    @ObservationIgnored
    private var cancellables: Set<AnyCancellable> = .init()
    
    /// Registers a generic `Publisher` and defines a closure to handle its output on the main thread.
    ///
    /// - Parameters:
    ///   - publisher: A `Publisher` that emits values to be processed.
    ///   - sink: A closure that receives and processes each emitted value on the main actor.
    public func registerPublisher<T: Publisher>(_ publisher: T, sink: @escaping (T.Output) -> Void) where T.Failure == Never {
        publisher
            .receive(on: RunLoop.main)
            .sink(receiveValue: sink)
            .store(in: &cancellables)
    }
    
    /// Registers a `Publisher` emitting `Double` values, typically representing progress updates.
    ///
    /// Each new `Double` output updates the `executionState` to `.installing(progress:)` and broadcasts
    /// that state through `stateSubject`. This pattern helps reflect installation or setup progress in real time.
    ///
    /// - Parameter publisher: A `Publisher` emitting progress values (`Double`), often from a `Progress` object.
    func registerPublisher<T: Publisher>(_ publisher: T) where T.Output == Double,
                                                               T.Failure == Never {
        registerPublisher(publisher) { [weak self] progress in
            
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
    func registerPublisher<T: Publisher>(_ publisher: T) where T.Output == VZVirtualMachine.State,
                                                               T.Failure == Never {
        
        registerPublisher(publisher) { [weak self] newVZState in
            
            guard let newExecutionState = ExecutionState(newVZState) else { return }
            
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
    func registerPublisher<T: Publisher>(_ publisher: T) where T.Output == Error,
                                                               T.Failure == Never {
        registerPublisher(publisher) { [weak self] error in
            
            self?.executionState = .error(error: error)
            self?.stateSubject.send(.error(error: error))
        }
    }
}
