//
//  VirtualMachineDelegate.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 15/05/24.
//
 
import Virtualization

/// `VirtualMachineDelegate` class, implements `VZKitMachineDelegate`
///
/// @brief
///    This class needs to be both a delegate for `VZVirtualMachine` and a publisher, in order to be able to perform
///    UI updates according to value changes of the state property.
///
///    - Important: `NSObject` conformation is also needed since the object inherits from another Objective-C protocol.
@Observable public final class VirtualMachineDelegate: NSObject, VZKitMachineDelegate {
    
    /// This variable holds the shared state that will be used to update views (specifically `MachineView`).
    /// Only the parent class should be able to set its value (private setter).
    ///
    /// - Important: This variable is pinned to @MainActor for thread-safe access.
    ///   We used a `DispatchSemaphore` before this aproach. Not the best solution.
    @MainActor public var state: VirtualMachineState = .stopped
    
    /// Setter method for the `state` property
    ///
    /// - Important: pinned to `@MainActor` to have synchronous access to the `state` property
    @discardableResult
    @MainActor public func updateState(_ newState: VirtualMachineState) -> VirtualMachineState {
        let oldState = state
        state = newState
        return oldState
    }
    
    /// `VZVirtualMachineDelegate` stub
    /// This is called after a graceful shutdown and pushes an update with `updateState(newState)`
    public func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        let newState = virtualMachine.state
        
        Task { @MainActor in updateState(newState) }
    }
    
    /// `VZVirtualMachineDelegate` stub
    /// This is called after a forceful shutdown (error) and pushes an update with `updateState(newState)`
    /// Also launches a task to present the error to the user.
    public func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: any Error) {
        let newState = virtualMachine.state
                
        Task { @MainActor in updateState(newState) }
    }
    
    /// Explicit initializer of the class
    ///
    /// - Parameters:
    ///   - state: The initial state (supposedly) of the virtual machine.
    @MainActor override init() {}
}
