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
//  StateCoordinator.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 09/11/24.
//

import Combine

import Virtualization

/// A protocol defining a main-actor-isolated coordinator for managing a virtual machine's execution state.
///
/// Conforming types must provide real-time tracking of the virtual machine's state (`executionState`), as well as
/// a mechanism (`stateSubject`) to broadcast state changes. Additionally, they may implement a method for registering
/// external Combine publishers to integrate updates, making this protocol suitable for bridging lower-level or
/// asynchronous APIs into a SwiftUI or Combine-based application.
///
/// By enforcing `@MainActor`, all state updates are guaranteed to occur on the main thread, preserving thread safety
/// and ensuring compatibility with UI-bound components.
@MainActor public protocol StateCoordinator {
    
    /// A Combine subject that broadcasts new `ExecutionState` values to observers.
    ///
    /// Implementers should use this subject to emit any state changes in conjunction with updates to `executionState`.
    nonisolated var stateSubject: PassthroughSubject<ExecutionState, Never> { get }
    
    /// The current execution state of the virtual machine.
    ///
    /// This property should be updated whenever a new state is detected. Observers can rely on this value
    /// to reflect or respond to changes in the VM lifecycle (e.g., running, stopped, installing, or errored).
    var executionState: ExecutionState { get }
}
