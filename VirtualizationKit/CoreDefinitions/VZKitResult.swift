//
//  VZKitResult.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 12/10/24.
//

import Virtualization

/// An enumeration representing the result of a virtual machine initialization within the `VirtualizationKit` framework.
///
/// `VZKitResult` provides a structured way to handle the outcome of virtual machine creation operations.
/// It encapsulates either a successfully created `VirtualMachine` instance or an `Error` encountered during
/// the initialization process. This design simplifies error propagation and handling by eliminating the need
/// to throw or catch errors explicitly, allowing for more straightforward control flow in your application.
///
/// - Note: The `TemplateType` must conform to `VZKitTemplate`.
///
/// - Important: You generally don't create this object directly, but use the VirtualMachine.createMachine static factory method instead.
public enum VZKitResult<TemplateType: VZKitTemplate>: Sendable {
    
    /// A case representing a failed attempt to initialize a virtual machine.
    ///
    /// - Parameter error: The error encountered during the virtual machine creation process.
    case failure(Error)
    
    /// A case representing a successful initialization of a virtual machine.
    ///
    /// - Parameter machine: An instance of `VirtualMachine` parameterized by `TemplateType`, indicating successful creation.
    case success(VirtualMachine<TemplateType>)
    
    /// The error encountered during virtual machine initialization, if any.
    ///
    /// - Returns: the associated `Error` if the result is `.failure`; otherwise, returns `nil`.
    public var error: Error? {
        
        if case .failure(let error) = self {
            return error
        }
        
        return nil
    }
    
    /// The successfully created virtual machine, if available.
    ///
    /// - Returns: the associated `VirtualMachine<TemplateType>` if the result is `.success`; otherwise, returns `nil`.
    public var machine: VirtualMachine<TemplateType>? {
        
        if case .success(let machine) = self {
            return machine
        }
        
        return nil
    }
    
    /// The current state of the virtual machine, suitable for display in views.
    ///
    /// If the outcome of the initialization is a success then we can simply forward the state from the virtual machine's own
    /// `MachineStateManager` instance. If the outcome is a failure it returns `.error`.
    ///
    /// - Important: This property must be accessed on the main thread.
    /// - Returns: Either a `MachineState` forwarded directly from the virtual machine state manager, or `.error` in case o failure.
    @MainActor public var state: MachineState {
        
        if case .success(let machine) = self {
            return machine.stateManager.currentState
        }
        
        return .error
     }
    
    /// The `progress` computed property provides the current progress of the virtual machine’s operation as a percentage.
    ///
    /// This property is marked with `@MainActor` to ensure it is accessed on the main thread, which is essential for UI-bound contexts.
    /// It returns the progress as an integer, representing the completion percentage, calculated based on the virtual machine’s
    /// state manager. If the virtual machine is in a `.success` state, it converts the `progress` value from `stateManager`
    /// (a `Double` between 0 and 1) into an integer percentage. If the virtual machine is in any other state, the progress defaults to 0.
    ///
    /// - Returns: An integer representing the progress percentage (0-100) if available; otherwise, 0 if progress data is not accessible.
    @MainActor public var progress: Int {
        
        if case .success(let machine) = self {
            return Int(machine.stateManager.progress * 100)
        }
        
        return 0
    }
}
