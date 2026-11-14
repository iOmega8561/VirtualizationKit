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
//  VZUSBMassStorageDeviceConfiguration.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 17/05/24.
//

import Virtualization

extension VZUSBMassStorageDeviceConfiguration: PersistentConstructible {
    
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
    static func create(at path: URL, type: MountingOptions) throws -> Product {
        
        let attachment = try VZDiskImageStorageDeviceAttachment(
            url: path,
            readOnly: type == .readOnly ? true : false
        )
        
        return Product(attachment: attachment)
    }
}
