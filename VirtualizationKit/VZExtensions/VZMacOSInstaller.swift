//
//  VZMacOSInstaller.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 01/05/24.
//

import Virtualization

/// An extension to `VZMacOSInstaller` that provides an asynchronous method for initiating macOS installation.
///
/// This extension adds support for Swift's concurrency model by wrapping the callback-based
/// `install(completionHandler:)` method into an `async` function. This allows developers to use modern
/// Swift concurrency features, such as `async/await`, to simplify the installation process.
///
/// ## Usage
/// ```swift
/// do {
///     let installer = VZMacOSInstaller(...)
///     try await installer.install()
///     print("Installation completed successfully.")
/// } catch {
///     print("Installation failed with error: \(error)")
/// }
/// ```
///
/// ## Implementation Details
/// - This method uses `withCheckedThrowingContinuation` to bridge the callback-based `install` method into the `async` world.
/// - Errors are propagated as thrown exceptions. If the `NSError` contains underlying errors, the first underlying error is thrown.
///
/// ## Considerations
/// - Ensure this method is called from a context where Swift's concurrency model is supported.
/// - Asynchronous methods must be called using `await`.
public extension VZMacOSInstaller {
    
    /// Asynchronously installs macOS using a virtual machine configuration.
    ///
    /// This method starts the macOS installation process and suspends execution until the installation
    /// is completed or an error occurs. If the installation fails, the error is thrown to the caller.
    ///
    /// - Throws: An error if the installation process fails. If the underlying `NSError` contains
    ///   multiple underlying errors, the first one is thrown for better context.
    ///
    /// - Note: This method wraps the callback-based `install(completionHandler:)` method
    ///   into an `async` function to integrate with Swift's concurrency model.
    func install() async throws {
        
        return try await withCheckedThrowingContinuation { continuation in
            
            self.install { result in
                
                switch result {
                case let .failure(error as NSError):
                    
                    // If the error has underlying errors, throw the first one.
                    if let underlying = error.underlyingErrors.first {
                        continuation.resume(throwing: underlying)
                        
                    } else { continuation.resume(throwing: error) }

                default:
                    // Resume successfully if there's no error.
                    continuation.resume()
                }
            }
        }
    }
}
