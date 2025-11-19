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
//  VZMacOSRestoreImage.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 13/11/24.
//

@preconcurrency import Virtualization

/// An extension to `VZMacOSRestoreImage` that provides a
/// static async loader, tailored to Swift's concurrency model.
///
/// ### Concurrency Considerations
/// - Swift emits warnings that `VZMacOSRestoreImage` is non-Sendable when crossing
///   actor boundaries. However, because this loading method *creates* a brand-new
///   image instance with read-only properties, the concurrency risk is minimal:
///   there's no further mutation once the image is returned.
/// - If future versions of the framework introduce mutable state, this assumption
///   could break. Always check release notes and reevaluate if new properties
///   appear mutable or if new APIs allow mutating the image.
///
/// ### Usage Example
/// ```swift
/// do {
///     let restoreImage = try await VZMacOSRestoreImage.load(from: url)
/// } catch {
///     print("Failed to load restore image: \(error)")
/// }
/// ```
///
/// - Note: If your app needs to pass `VZMacOSRestoreImage` across multiple actors
///   frequently, consider wrapping its data in a `Sendable` type or marking it
///   `@unchecked Sendable` (with caution).
extension VZMacOSRestoreImage {
    
    /// Asynchronously loads a `VZMacOSRestoreImage` from a specified URL.
    ///
    /// This method wraps the completion-based API of `VZMacOSRestoreImage.load(from:completion:)`
    /// in Swift’s async/await syntax, offering more readable asynchronous code.
    ///
    /// **Concurrency Note**: While `VZMacOSRestoreImage` is not officially marked as `Sendable`,
    /// this method only creates a new, read-only instance. For most use cases, this should
    /// pose no concurrency risk. If you share this instance across actors, be mindful of any
    /// potential future changes to the Virtualization framework that might introduce mutable state.
    ///
    /// - Parameter url: The URL from which to load the macOS restore image.
    /// - Returns: A `VZMacOSRestoreImage` instance loaded from the provided URL.
    /// - Throws: An error if the restore image could not be loaded from the specified URL.
    static func load(from url: URL) async throws -> VZMacOSRestoreImage {
        
        return try await withCheckedThrowingContinuation { continuation in
            
            VZMacOSRestoreImage.load(from: url) { result in
                
                switch result {
                case let .failure(error):
                    continuation.resume(throwing: error)
                    
                case let .success(systemImage):
                    continuation.resume(returning: systemImage)
                }
            }
        }
    }
}
