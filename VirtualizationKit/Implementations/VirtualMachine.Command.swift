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
    
    /// A `Command` is an enum representing operations that can be performed on a virtual machine.
    ///
    /// Each case represents a supported command for the default implementation of `VZKitVirtualMachine`.
    /// The `Command` provides metadata about its transition and final states via computed properties.
    ///
    /// - Cases:
    ///   - `start`: Transitions the machine from `.stopped` to `.running`.
    ///   - `stop`: Transitions the machine from `.stopping` to `.stopped`.
    ///   - `pause`: Transitions the machine from `.running` to `.paused`.
    ///   - `resume`: Transitions the machine from `.resuming` to `.running`.
    public enum Command: Sendable, CaseIterable {
        
        /// Encapsulates metadata for a command, including its transition and final states.
        private struct MetaData: Equatable {
            let transitionState: MachineState
            let finalState: MachineState?
        }
        
        case start
        case stop
        case pause
        case resume
        case install
        
        /// Private computed property providing the metadata for a command.
        private var metaData: MetaData {
            switch self {
            case .start: .init(transitionState: .stopped, finalState: .running)
            case .stop: .init(transitionState: .stopping, finalState: .stopped)
            case .pause: .init(transitionState: .running, finalState: .paused)
            case .resume: .init(transitionState: .resuming, finalState: .running)
            case .install: .init(transitionState: .restoring, finalState: nil)
            }
        }
        
        /// The transition state associated with the command.
        var transitionState: MachineState { metaData.transitionState }
        
        /// The final state associated with the command.
        var finalState: MachineState? { metaData.finalState }
    }
}
