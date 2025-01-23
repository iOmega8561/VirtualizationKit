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
    /// of a virtual machine. This enum is particularly useful for building systems or APIs that need to control
    /// a virtual machine’s lifecycle, ensuring valid transitions between states.
    ///
    /// ## Features
    /// - `Sendable`: The `Command` enum is `Sendable`, meaning it can safely be used in Swift's
    ///   concurrency contexts.
    ///
    /// ## Use Cases
    /// - Managing virtual machine state transitions, such as starting, stopping, pausing, and resuming.
    /// - Integrating with UI controls or APIs for executing specific virtual machine operations.
    ///
    /// ## Enum Cases
    /// - `start`: Transitions the machine from `.stopped` to `.running`.
    /// - `stop`: Transitions the machine from `.stopping` to `.stopped`.
    /// - `pause`: Transitions the machine from `.running` to `.paused`.
    /// - `resume`: Transitions the machine from `.resuming` to `.running`.
    /// - `install`: Transitions the machine from `.restoring` to an undefined final state.
    public enum Command: VZKitTransferable {
        
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
        
    }

}
