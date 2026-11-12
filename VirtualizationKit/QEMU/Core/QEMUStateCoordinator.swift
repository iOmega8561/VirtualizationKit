//
//  Copyright 2026 Giuseppe Rocco
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

import Foundation

import Observation

@unsafe @preconcurrency import Combine

/// The main-actor-isolated owner of a QEMU virtual machine's execution state.
///
/// It mirrors the coordinator of the Apple backend from the outside: an observable `executionState`
/// plus a Combine subject broadcasting every change. The difference is where the changes come from.
/// QEMU has no object to observe; its state is derived from the lifecycle of the emulator process and
/// from the events it reports over its control channel, and is pushed in through `transition(to:)`.
@MainActor @Observable
public final class QEMUStateCoordinator: StateCoordinator {

    /// A Combine subject that broadcasts updates to the virtual machine's execution state.
    ///
    /// Although declared as `nonisolated`, updates originate from the main actor.
    @ObservationIgnored
    nonisolated public let stateSubject: PassthroughSubject<ExecutionState, Never> = .init()

    /// The current execution state of the virtual machine.
    public private(set) var executionState: ExecutionState = .stopped

    /// Moves to a new state and broadcasts it, unless it is the state the machine is already in.
    ///
    /// - Parameter newState: The state to move to.
    func transition(to newState: ExecutionState) {
        guard newState != executionState else { return }

        self.executionState = newState
        self.stateSubject.send(newState)
    }
}
