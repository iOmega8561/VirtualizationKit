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
//  VZLinuxRosettaDirectoryShare.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 17/05/24.
//

import Virtualization

extension VZLinuxRosettaDirectoryShare: GenericConstructible {
    
    typealias Product = VZVirtioFileSystemDeviceConfiguration
    
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
    static func create() throws -> Product {
                
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
            throw VZKitError.unsupportedFeature(.rosetta)
            
        case .notInstalled:
            fallthrough
            
        default:
            throw VZKitError.unavailableFeature(.rosetta)
        }
    }
}
