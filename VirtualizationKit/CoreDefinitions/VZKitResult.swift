//
//  VZKitResult.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 12/10/24.
//

import Virtualization

/// An enumeration encapsulating the outcome of creating a virtual machine instance using a
/// `VZKitVirtualMachine`-conforming type.
///
/// `VZKitResult` serves as a high-level container for handling the two possible outcomes of VM
/// initialization: either a fully realized `VirtualMachine` or an `Error` indicating what went wrong.
/// This design simplifies error propagation by eliminating the need to throw or catch errors
/// immediately, enabling more linear control flow—particularly useful in SwiftUI or other UI-bound
/// contexts where preserving and later presenting an error is desirable.
///
/// - Note: The associated `VirtualMachine` must specify a `Template` conforming to `VZKitTemplate`.
/// - Important: While you can instantiate `VZKitResult` directly through its initializer,
///   it is more common to invoke a factory method (e.g., `createMachine(template:)`) that returns
///   this result, centralizing the creation logic and error handling in a single call.
///
/// - Parameters:
///   - VirtualMachine: A type conforming to `VZKitVirtualMachine` used in the result.
@frozen public enum VZKitResult<VirtualMachine: VZKitVirtualMachine>: Sendable {
    
    /// Indicates that the VM creation process encountered an error.
    ///
    /// - Parameter error: The `Error` detailing the cause of the failure during initialization.
    case failure(Error)
    
    /// Indicates that the VM was successfully initialized.
    ///
    /// - Parameter machine: A fully configured `VirtualMachine` instance resulting from a valid template.
    case success(VirtualMachine)
    
    /// Retrieves the error from a failed initialization, if present.
    ///
    /// Returns `nil` if the result was `.success`.
    public var error: Error? {
        switch self {
        case .failure(let error): return error
        default: return nil
        }
    }
    
    /// Retrieves the successfully created VM, if present.
    ///
    /// Returns `nil` if the result was `.failure`.
    public var virtualMachine: VirtualMachine? {
        switch self {
        case .success(let vm): return vm
        default: return nil
        }
    }
    
    /// Asynchronously attempts to initialize a `VirtualMachine` from the specified `template`,
    /// storing the outcome in either the `.success` or `.failure` case.
    ///
    /// - Parameter template: A configuration object conforming to `VZKitTemplate`, describing
    ///   how to provision and launch the virtual machine.
    /// - Note: The resulting `VZKitResult` preserves any error encountered during creation,
    ///   enabling you to store and present it later—especially useful in UI contexts.
    public init(template: VirtualMachine.Template) async {
        do {
            self = try await .success(VirtualMachine(template: template))
            
        } catch { self = .failure(error) }
    }
}
