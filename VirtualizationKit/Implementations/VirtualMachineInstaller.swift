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
//  VirtualMachineInstaller.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 01/05/24.
//

import Combine

@preconcurrency import Virtualization

/// `VirtualMachineInstaller` struct, implements `VZKitMachineInstaller`
///
/// @brief
///    This struct contains the necessary facilities to install macOS, having a valid restore image.
///
///    - Important: `VZVirtualMachine` IS NOT sendable. We import the `Virtualization` framework using `@preconcurrency`.
public struct VirtualMachineInstaller: VZKitMachineInstaller {
    
    /// Reference to a `URL` that will point to the location of the restore image, on the host file system.
    public let restoreImage: URL
    
    /// Reference to a `VZVirtualMachine` on which will be performed the installation process.
    public let machine: VZVirtualMachine
    
    /// The master installation method.
    ///
    /// @brief
    ///    The installer is pinned on `@VZKitVirtualMachine` to execute on the same queue as the one provided to the VM initializer
    ///    Since the `Virtualization` framework, in this case, does not support structured concurrency, we use a checked continuation.
    @VZKitGlobalActor public func startInstallation() async throws {
                
        return try await withCheckedThrowingContinuation { continuation in
            
            let installer = VZMacOSInstaller(
                virtualMachine: machine,
                restoringFromImageAt: self.restoreImage
            )
            
            installer.install { result in
                switch result {
                case let .failure(error):
                    continuation.resume(throwing: error)
                default:
                    continuation.resume()
                }
            }
        }
    }
    
    /// The explicit initializer of the class. Checks if the restore image file exists, otherwise it throws an exception.
    ///
    /// - Parameters:
    ///   - restoreImage: The `URL` that will point to the location of the restore image, on the host file system.
    ///   - machine: The`VZVirtualMachine` on which will be performed the installation process.
    init(restoreImage: URL?, machine: VZVirtualMachine) throws {
        
        guard let restoreImage else {
            throw VZKitError.missingMacImage
        }
        
        guard FileManager.default.fileExists(atPath: restoreImage.path) else {
            throw VZKitError.missingMacImage
        }
        
        self.restoreImage = restoreImage
        self.machine = machine
    }
}
