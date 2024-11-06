//
//  VZKitMachineDelegate.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 14/05/24.
//

import Virtualization

/// VZKitMachineDelegate protocol
///
/// @brief
///    This protocol defines how a Virtual Machine delegate should be implemented in this application
public protocol VZKitMachineDelegate: VZVirtualMachineDelegate, Sendable {
    
    associatedtype StateType : VZKitMachineState
    
    /// This variable holds the shared state that will be used to update views (specifically `MachineView`).
    /// Only the parent class should be able to set its value (private setter).
    ///
    /// - Important: This variable is pinned to @MainActor for thread-safe access.
    @MainActor var state: StateType { get }
    
    /// Setter method for the `state` property
    ///
    /// - Important: pinned to `@MainActor` to have synchronous access to the `state` property.
    ///   Returns the old value of `state`, can be eventually discarded without having the compiler complain.
    @discardableResult @MainActor func updateState(_ newState: StateType) -> StateType
    
    /// `VZVirtualMachineDelegate` stub
    /// This is called after a graceful shutdown.
    func guestDidStop(_ virtualMachine: VZVirtualMachine)
    
    /// `VZVirtualMachineDelegate` stub
    /// This is called after a forceful shutdown (error).
    func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: any Error)
}
