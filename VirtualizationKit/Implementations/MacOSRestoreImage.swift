//
//  MacOSRestoreImage.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 13/11/24.
//

@preconcurrency import Virtualization

typealias MacOSRestoreImage = VZMacOSRestoreImage

extension MacOSRestoreImage: VZKitRestoreImage {
    
    public var osVersion: OperatingSystem.Version {
        return .init(self.operatingSystemVersion)
    }
    
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
