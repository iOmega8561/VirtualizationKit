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
//  VZDirectorySharingDeviceConfiguration.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 17/05/24.
//

import Virtualization

extension VZDirectorySharingDeviceConfiguration: PersistentConstructible {
    
    typealias Product = VZVirtioFileSystemDeviceConfiguration
    
    /// This method can create a shared directory mount between the host and the guest systems.
    /// Sets the appropriate tag depending on the chosen guest operating system, for example to support
    /// auto-mounting features on macOS guests, and returns the attachment to the caller.
    ///
    /// - Parameters:
    ///   - url: The location at which the shared mount should be created on the host file system.
    ///   - type: The guest operating system.
    static func create(at url: URL, type: OperatingSystem) throws -> Product {
        
        try FileManager.default.createDirectory(
            atPath: url.path(percentEncoded: false),
            withIntermediateDirectories: true
        )
        
        let sharedDirectory = VZSharedDirectory(
            url: url,
            readOnly: false
        )
        
        let singleDirectoryShare = VZSingleDirectoryShare(directory: sharedDirectory)
        
        let sharingDevice: Product
        
        switch type {
        case .macos(let version):
            
            guard version.major > 12 else {
                throw VZKitError.unsupportedFeature(.directoryShare)
            }
            
            sharingDevice = .init(
                tag: Product.macOSGuestAutomountTag
            )
            
        default:
            sharingDevice = .init(tag: "DEFAULT_SHARE")
            
        }
        
        sharingDevice.share = singleDirectoryShare
        
        return sharingDevice
    }
}
