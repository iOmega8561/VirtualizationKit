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
//  VZLinuxRosettaDirectoryShare.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 17/05/24.
//

import Virtualization

extension VZLinuxRosettaDirectoryShare: VZKitGenericConstructible {
    
    typealias Constructible = VZVirtioFileSystemDeviceConfiguration
    
    /// Creates a shared directory mount between the host and the guest systems using Apple Rosetta.
    ///
    /// This method checks the availability of Rosetta on the host system and, if supported, initializes a shared
    /// directory using `VZLinuxRosettaDirectoryShare`. The shared directory is configured with caching options and
    /// returned as a `FileSystemDevice`.
    ///
    /// - Returns: A configured `FileSystemDevice` representing the shared directory mount.
    ///
    /// - Throws:
    ///   - `VZKitError.rosettaUnsupported` if Rosetta is not supported on the host system.
    ///   - `VZKitError.rosettaUnavailable` if Rosetta is not installed or another unsupported state is encountered.
    ///   - Errors thrown by `VZLinuxRosettaDirectoryShare` during initialization or configuration.
    ///
    /// - Note:
    ///   Ensure that Rosetta is installed and supported on the host system before calling this method.
    static func create() throws -> Constructible {
                
        switch VZLinuxRosettaDirectoryShare.availability {
        case .installed:
            let rosettaDirectoryShare = try VZLinuxRosettaDirectoryShare()
            
            try rosettaDirectoryShare.setCachingOptions(
                .abstractSocket("rosettaSocket")
            )
            
            let sharingDevice = VZVirtioFileSystemDeviceConfiguration(
                tag: "ROSETTA_SHARE"
            )
            
            sharingDevice.share = rosettaDirectoryShare
            return sharingDevice
            
        case .notSupported:
            throw VZKitError.hostFeatureUnsupported("Rosetta")
            
        case .notInstalled:
            fallthrough
            
        default:
            throw VZKitError.rosettaUnavailable
        }
    }
}
