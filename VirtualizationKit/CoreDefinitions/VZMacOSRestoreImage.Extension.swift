//
//  VZMacOSRestoreImage.Extension.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 13/11/24.
//

@preconcurrency import Virtualization

extension VZMacOSRestoreImage {
    
    public var osVersion: OperatingSystem.Version {
        return .init(self.operatingSystemVersion)
    }
    
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
