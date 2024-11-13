//
//  Copyright (C) Giuseppe Rocco - All Rights Reserved
//  Unauthorized copying, modification or distribution of this source code,
//  via any medium is strictly prohibited and penally persecutable
//
//  This project and its source code are PROPRIETARY AND CONFIDENTIAL
//  Written by Giuseppe Rocco <giusepperocco38@gmail.com>, May 2024
//
//  -----------------------------------------------------------------------
//
//  MacOSRestoreImage.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 13/11/24.
//

@preconcurrency import Virtualization

/// A typealias for `VZMacOSRestoreImage`, representing a macOS restore image used in virtualization configurations.
typealias MacOSRestoreImage = VZMacOSRestoreImage

/// Extension to provide additional functionality to `MacOSRestoreImage`, conforming it to `VZKitRestoreImage`.
extension MacOSRestoreImage: VZKitRestoreImage {
    
    /// The version of the macOS operating system associated with this restore image.
    ///
    /// This computed property converts the `operatingSystemVersion` of the restore image
    /// to a custom `OperatingSystem.Version` type.
    ///
    /// - Returns: An `OperatingSystem.Version` instance that represents the macOS version
    ///            of the restore image.
    public var osVersion: OperatingSystem.Version {
        return .init(self.operatingSystemVersion)
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
            
            MacOSRestoreImage.load(from: url) { result in
                
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
