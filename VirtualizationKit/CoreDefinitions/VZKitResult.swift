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
/// - Note: The `Template` must conform to `VZKitTemplate`.
///
/// - Important: You generally don't create this object directly, but use the VirtualMachine.createMachine static factory method instead.
public enum VZKitResult<Template: VZKitTemplate>: Sendable {
    
    /// A case representing a failed attempt to initialize a virtual machine.
    ///
    /// - Parameter error: The error encountered during the virtual machine creation process.
    case failure(Error)
    
    /// A case representing a successful initialization of a virtual machine.
    ///
    /// - Parameter machine: An instance of `VirtualMachine` parameterized by `Template`, indicating successful creation.
    case success(VirtualMachine<Template>)
    
    /// The error encountered during virtual machine initialization, if any.
    ///
    /// - Returns: the associated `Error` if the result is `.failure`; otherwise, returns `nil`.
    public var error: Error? {
        switch self {
        case .failure(let error): error
        default: nil
        }
    }
    
    /// The successfully created virtual machine, if available.
    ///
    /// - Returns: the associated `VirtualMachine<Template>` if the result is `.success`; otherwise, returns `nil`.
    public var virtualMachine: VirtualMachine<Template>? {
        
        switch self {
        case .success(let virtualMachine): virtualMachine
        default: nil
        }
    }
    
    /// The current state of the virtual machine, suitable for display in views.
    ///
    /// If the outcome of the initialization is a success then we can simply forward the state from the virtual machine's own
    /// `ObservableCoordinator` instance. If the outcome is a failure it returns `.error`.
    ///
    /// - Important: This property must be accessed on the main thread.
    /// - Returns: Either a `ExecutionState` forwarded directly from the virtual machine state coordinator,
    /// or `.error` in case o failure.
    /// - Note: This computed property propagates state changes thanks to
    /// `ObservableCoordinator` being marked with `@Observable`.
    @MainActor public var state: ExecutionState {
        
        switch self {
        case .success(let virtualMachine): virtualMachine.stateCoordinator.currentState
        case .failure(let error): .error(error: error)
        }
     }
}
