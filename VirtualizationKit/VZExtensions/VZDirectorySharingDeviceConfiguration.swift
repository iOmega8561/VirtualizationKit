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
//  VZDirectorySharingDeviceConfiguration.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 17/05/24.
//

import Virtualization

extension VZDirectorySharingDeviceConfiguration: VZKitPersistentConstructible {
    
    typealias Constructible = VZVirtioFileSystemDeviceConfiguration
    
    /// This method can create a shared directory mount between the host and the guest systems.
    /// Sets the appropriate tag depending on the chosen guest operating system, for example to support
    /// auto-mounting features on macOS guests, and returns the attachment to the caller.
    ///
    /// - Parameters:
    ///   - url: The location at which the shared mount should be created on the host file system.
    ///   - type: The guest operating system.
    static func create(at url: URL, type: VZKitOperatingSystem) throws -> Constructible {
        
        try FileManager.default.createDirectory(
            atPath: url.path(percentEncoded: false),
            withIntermediateDirectories: true
        )
        
        let sharedDirectory = VZSharedDirectory(
            url: url,
            readOnly: false
        )
        
        let singleDirectoryShare = VZSingleDirectoryShare(directory: sharedDirectory)
        
        let sharingDevice: Constructible
        
        switch type {
        case .macos(let version):
            
            guard version.major > 12 else {
                throw VZKitError.unsupportedFeature(.directoryShare)
            }
            
            sharingDevice = .init(
                tag: Constructible.macOSGuestAutomountTag
            )
            
        default:
            sharingDevice = .init(tag: "DEFAULT_SHARE")
            
        }
        
        sharingDevice.share = singleDirectoryShare
        
        return sharingDevice
    }
}
