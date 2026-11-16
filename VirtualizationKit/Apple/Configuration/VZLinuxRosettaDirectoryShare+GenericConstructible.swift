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
//  VZLinuxRosettaDirectoryShare+GenericConstructible.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 17/05/24.
//

import Virtualization

extension VZLinuxRosettaDirectoryShare: GenericConstructible {
    
    typealias Product = VZVirtioFileSystemDeviceConfiguration
    
    /// Creates a shared directory mount between the host and the guest systems using Apple Rosetta.
    ///
    /// The shared directory is configured with caching options and returned as a `FileSystemDevice`.
    ///
    /// - Note: Whether Rosetta can be used is decided by `AppleConfigurationBuilder.validate`, which
    ///   runs before any device is created, so it is not checked again here.
    ///
    /// - Returns: A configured `FileSystemDevice` representing the shared directory mount.
    /// - Throws: Errors thrown by `VZLinuxRosettaDirectoryShare` during initialization or configuration.
    static func create() throws -> Product {

        let rosettaDirectoryShare = try VZLinuxRosettaDirectoryShare()

        try rosettaDirectoryShare.setCachingOptions(
            .abstractSocket("rosettaSocket")
        )

        let sharingDevice = VZVirtioFileSystemDeviceConfiguration(
            tag: "ROSETTA_SHARE"
        )

        sharingDevice.share = rosettaDirectoryShare
        return sharingDevice
    }
}
