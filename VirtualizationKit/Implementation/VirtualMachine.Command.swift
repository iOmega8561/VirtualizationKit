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
//  VirtualMachine.Command.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 07/01/25.
//

import Virtualization

extension VirtualMachine {
    
    /// A `Command` represents operations that can be performed on a virtual machine.
    ///
    /// The `Command` enum defines a set of operations that correspond to specific state transitions
    /// of a virtual machine. Each case encapsulates the transition and final states associated
    /// with the command, providing a clear and structured way to describe VM operations.
    ///
    /// This enum is particularly useful for building systems or APIs that need to control
    /// a virtual machine’s lifecycle, ensuring valid transitions between states.
    ///
    /// ## Features
    /// - `Sendable`: The `Command` enum is `Sendable`, meaning it can safely be used in Swift's
    ///   concurrency contexts.
    /// - `CaseIterable`: All command cases are accessible programmatically via `Command.allCases`.
    /// - State Transition Metadata: Each command provides information about its:
    ///   - **Transition State**: The intermediate state the virtual machine enters during the command.
    ///   - **Final State**: The desired state after the command completes (if applicable).
    ///
    /// ## Use Cases
    /// - Managing virtual machine state transitions, such as starting, stopping, pausing, and resuming.
    /// - Integrating with UI controls or APIs for executing specific virtual machine operations.
    /// - Validating allowed transitions by examining the `transitionState` and `finalState` of a command.
    ///
    /// ## Enum Cases
    /// - `start`: Transitions the machine from `.stopped` to `.running`.
    /// - `stop`: Transitions the machine from `.stopping` to `.stopped`.
    /// - `pause`: Transitions the machine from `.running` to `.paused`.
    /// - `resume`: Transitions the machine from `.resuming` to `.running`.
    /// - `install`: Transitions the machine from `.restoring` to an undefined final state.
    ///
    /// ## Example Usage
    /// ```swift
    /// let command: Command = .start
    /// print("Transition State: \(command.transitionState)")
    /// print("Final State: \(command.finalState ?? .unknown)")
    /// ```
    ///
    /// - Note: The `install` case represents an operation where the final state is not explicitly defined,
    ///         making it suitable for processes like initial setups or installations.
    public enum Command: VZKitTransferable {
        
        // MARK: - Supporting Structures
        
        /// Encapsulates metadata for a command, including its transition and final states.
        ///
        /// The `MetaData` struct is used internally to associate each command with its corresponding
        /// state transition information, ensuring clean separation of metadata from the command cases.
        private struct MetaData: Equatable {
            /// The intermediate state entered during the execution of the command.
            let transitionState: VZVirtualMachine.State
            /// The desired final state of the virtual machine after the command completes.
            let finalState: VZVirtualMachine.State?
        }
        
        // MARK: - Command Cases
        
        /// Transitions the machine from `.stopped` to `.running`.
        case start
        /// Transitions the machine from `.stopping` to `.stopped`.
        case stop
        /// Transitions the machine from `.running` to `.paused`.
        case pause
        /// Transitions the machine from `.resuming` to `.running`.
        case resume
        /// Transitions the machine from `.restoring` to an undefined final state.
        case install
        
        // MARK: - Private Metadata
        
        /// Provides metadata for each command, including transition and final states.
        ///
        /// This private computed property maps each `Command` case to its corresponding metadata.
        private var metaData: MetaData {
            switch self {
            case .start: return .init(transitionState: .stopped, finalState: .running)
            case .stop: return .init(transitionState: .stopping, finalState: .stopped)
            case .pause: return .init(transitionState: .running, finalState: .paused)
            case .resume: return .init(transitionState: .resuming, finalState: .running)
            case .install: return .init(transitionState: .restoring, finalState: nil)
            }
        }
        
        // MARK: - Public Properties
        
        /// The transition state associated with the command.
        ///
        /// This property provides the intermediate state the virtual machine enters
        /// during the execution of the command. For example, when executing `.start`,
        /// the transition state is `.stopped`.
        var transitionState: VZVirtualMachine.State {
            metaData.transitionState
        }
        
        /// The final state associated with the command.
        ///
        /// This property represents the desired state of the virtual machine after the
        /// command completes. If a command does not define a specific final state, such as `.install`,
        /// this property will be `nil`.
        var finalState: VZVirtualMachine.State? {
            metaData.finalState
        }
    }

}
