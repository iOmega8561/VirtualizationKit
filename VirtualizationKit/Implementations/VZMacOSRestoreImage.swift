//
//  VZMacOSRestoreImage.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 13/11/24.
//

@preconcurrency import Virtualization

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
    /// This method uses Swift's async/await pattern to wrap the completion-based `load(from:)` method
    /// of `MacOSRestoreImage`, allowing for cleaner and more readable asynchronous code.
    ///
    /// - Parameter url: The URL from which to load the macOS restore image.
    /// - Returns: A `VZMacOSRestoreImage` instance loaded from the provided URL.
    /// - Throws: An error if the restore image could not be loaded from the specified URL.
    ///
    /// This method handles the result of the load operation by resuming a continuation
    /// with either a `VZMacOSRestoreImage` on success or an error on failure.
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
