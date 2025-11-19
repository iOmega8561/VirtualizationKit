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
//  VZKitResult.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 12/10/24.
//

import Virtualization

/// An enumeration representing the outcome of initializing a virtual machine instance.
///
/// `VZKitResult` serves as a high-level container that encapsulates the result of creating a virtual
/// machine conforming to `VirtualMachine`. The result is either a successfully initialized virtual
/// machine (wrapped as an existential of type `any VirtualMachine`) or an error that occurred during
/// the initialization process.
///
/// This design simplifies error handling by capturing initialization failures within the result itself,
/// rather than requiring immediate error throwing. This pattern is especially useful in UI-bound contexts
/// (e.g., SwiftUI applications), where you may wish to preserve and later present errors.
///
/// ### Provided Properties
/// - `error`: If the result represents a failure, this property returns the associated error; otherwise, it returns `nil`.
/// - `virtualMachine`: If the result represents success, this property returns the initialized virtual machine; otherwise, it returns `nil`.
///
/// ### Asynchronous Initializer
///
/// The asynchronous initializer attempts to create a virtual machine using the provided configuration template.
/// It accepts:
///
/// - `vmType`: The concrete type of the virtual machine to be created. This type must conform to `VirtualMachine`.
/// - `template`: A configuration object conforming to `TransferableTemplate` that specifies the settings for the virtual machine.
///
/// The initializer uses the `init(template:)` method on the specified `vmType`. If the initialization is successful,
/// the instance is stored in the `.success` case; if an error occurs, it is captured in the `.failure` case.
///
/// - Note: The associated `Template` type of the virtual machine must match the type of the provided `template`.
///
/// ### Usage Example
/// ```swift
/// let result = await VZKitResult(MyVirtualMachine.self, using: myTemplate)
/// if let vm = result.virtualMachine {
///     // Use the successfully created virtual machine.
/// } else if let error = result.error {
///     // Handle the initialization error.
/// }
/// ```
///
/// Conformance to `Sendable` ensures that `VZKitResult` can be safely used in concurrent environments.
@frozen
public enum VZKitResult: Sendable {
    
    /// Indicates that the virtual machine initialization process encountered an error.
    ///
    /// - Parameter error: The `Error` detailing what went wrong during initialization.
    case failure(Error)
    
    /// Indicates that the virtual machine was successfully initialized.
    ///
    /// - Parameter machine: A fully configured virtual machine instance, stored as an existential of type `any VirtualMachine`.
    case success(any VirtualMachine)
    
    /// Retrieves the error from a failed initialization, if available.
    ///
    /// Returns `nil` if the result is `.success`.
    public var error: Error? {
        switch self {
        case .failure(let error): error
        default: nil
        }
    }
    
    /// Retrieves the successfully created virtual machine, if available.
    ///
    /// Returns `nil` if the result is `.failure`.
    public var virtualMachine: (any VirtualMachine)? {
        switch self {
        case .success(let virtualMachine): virtualMachine
        default: nil
        }
    }
    
    /// Asynchronously initializes a `VZKitResult` by attempting to create a virtual machine instance
    /// using the provided configuration template.
    ///
    /// This initializer takes a specific virtual machine type and a configuration object, then attempts
    /// to create the virtual machine via its `init(template:)` initializer. If the initialization succeeds,
    /// the result is stored in the `.success` case of `VZKitResult`; if an error occurs, it is captured in
    /// the `.failure` case.
    ///
    /// - Parameters:
    ///   - vmType: The concrete type of the virtual machine to be created. This type must conform to `VirtualMachine`.
    ///   - template: A configuration object conforming to `TransferableTemplate` that specifies the settings for the virtual machine.
    /// - Note: The associated `Template` type of the virtual machine must match the type of the provided `template`.
    /// - Usage:
    ///   ```swift
    ///   let result = await VZKitResult(MyVirtualMachine.self, using: myTemplate)
    ///   ```
    /// - Important: This initializer does not throw errors directly; instead, any errors encountered during
    ///   initialization are captured within the resulting `VZKitResult` instance.
    public init<
        Product: VirtualMachine,
        Template: TransferableTemplate
    >(
        _ vmType: Product.Type,
        using template: Template
    )
    async where Product.Template == Template {
        do {
            self = .success(
                try await vmType.init(template: template)
            )
        } catch {
            
            self = .failure(error)
        }
    }
}
