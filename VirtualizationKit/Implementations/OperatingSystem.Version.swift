//
//  OperatingSystem.Version.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 12/11/24.
//

import Virtualization

extension OperatingSystem {
    
    /// This data structure is useful to provide a standardized way to store information about
    /// the version of the guest operating system. It conforms to:
    /// - Equatable so that two instances can be compared easily.
    /// - Codable is needed so that it can be easily integrated with standard storage systems.
    /// - Sendable is useful to silence the Swift compiler. The struct is thread safe.
    /// - Hashable so it can be integrated as enum case associated value without complications.
    public struct Version: VZKitOperatingSystemVersion {
        
        /// Static utility method to retrieve an `OperatingSytem.Version` tuple, using information parsed from
        /// the provided macOS restore image (if present). It allows to manipulate the enum cases to have them store things like OS version.
        ///
        /// - Parameters:
        ///   - url: The URL of the installer image provided by the caller. if the image is not a macOS .ipsw the method will throw
        public static func fromImage(withURL url: URL) async throws -> Self {
            
            return try await withCheckedThrowingContinuation { continuation in
                
                VZMacOSRestoreImage.load(from: url) { result in
                    switch result {
                        
                    case .failure(let error):
                        continuation.resume(throwing: error)
                        
                    case .success(let restoreImage):
                        
                        let version: Version = .init(
                            major: restoreImage.operatingSystemVersion.majorVersion,
                            minor: restoreImage.operatingSystemVersion.minorVersion,
                            patch: restoreImage.operatingSystemVersion.patchVersion
                        )
                        
                        continuation.resume(returning: version)
                    }
                }
            }
            
        }
        
        public let major: Int
        
        public let minor: Int
        
        public let patch: Int
    }
}
