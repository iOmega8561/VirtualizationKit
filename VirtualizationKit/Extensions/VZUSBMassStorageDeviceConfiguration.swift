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
//  VZUSBMassStorageDeviceConfiguration.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 17/05/24.
//

import Virtualization

extension VZUSBMassStorageDeviceConfiguration: VZKitStorageConstructible {
    
    /// When calling the factory method from the outside, this enum becomes very useful
    /// to provide concise information about read/write mounting permissions.
    enum MountingOptions {
        case readWrite
        case readOnly
    }
    
    /// This method can create a disk image attachment from the host file system.
    /// Useful to simulate optical drives with .ISO files.
    ///
    /// - Parameters:
    ///   - url: The location at which the disk image is located on the host file system.
    ///   - type: The mounting permissions of the disk image.
    static func create(at path: URL, type: MountingOptions) throws -> Constructible {
        
        let attachment = try VZDiskImageStorageDeviceAttachment(
            url: path,
            readOnly: type == .readOnly ? true : false
        )
        
        return Constructible(attachment: attachment)
    }
}
