//
//  VZMacOSRestoreImage.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 13/11/24.
//

@preconcurrency import Virtualization

/// An extension to `VZMacOSRestoreImage` that provides a custom version property
/// and a static async loader, tailored to Swift's concurrency model.
///
/// `VZMacOSRestoreImage` is presumed read-only based on Apple's current
/// Virtualization framework documentation. This extension:
///  1. Adds a utility property `osVersion` for cleaner access to the macOS version.
///  2. Provides a static async method `load(from:)` that wraps the framework's
///     completion-based API into an async/await flow.
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
///     print("Loaded macOS version: \(restoreImage.osVersion)")
/// } catch {
///     print("Failed to load restore image: \(error)")
/// }
/// ```
///
/// - Note: If your app needs to pass `VZMacOSRestoreImage` across multiple actors
///   frequently, consider wrapping its data in a `Sendable` type or marking it
///   `@unchecked Sendable` (with caution).
extension VZMacOSRestoreImage: VZKitRestorableImage {
    
    /// The version of the macOS operating system associated with this restore image.
    ///
    /// This computed property converts the `operatingSystemVersion` of the restore image
    /// to a custom `VZKitOperatingSystem.Version` type.
    ///
    /// - Returns: An `VZKitOperatingSystem.Version` instance that represents the macOS version
    ///            of the restore image.
    public var osVersion: VZKitOperatingSystem.Version {
        return .init(self.operatingSystemVersion, self.buildVersion)
    }
    
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
    public static func load(from url: URL) async throws -> VZMacOSRestoreImage {
        
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
