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
//  VZVirtioBlockDeviceConfiguration+PersistentConstructible.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 17/05/24.
//

import Virtualization

extension VZVirtioBlockDeviceConfiguration: PersistentConstructible {    
    
    /// When calling the factory method from the outside, this enum becomes very useful
    /// to provide concise information about disk capacity and read/write mounting permissions.
    enum MountingOptions {
        case readWrite(size: UInt64)
        case readOnly(size: UInt64)
    }
    
    /// This method can create a disk image and write it to the host file system.
    /// If a disk image already exists at the given location, it simply returns.
    ///
    /// - Parameters:
    ///   - url: The location at which the disk image should be created on the host file system.
    ///   - size: The integer size of the virtual disk image, in gigabytes.
    static private func createDiskImage(_ url: URL, _ size: UInt64) throws {
        
        let path = url.path(percentEncoded: false)
        
        guard !FileManager.default.fileExists(atPath: path) else { return }
        
        guard FileManager.default.createFile(
            atPath: path,
            contents: nil,
            attributes: nil
            
        ) else { throw VZKitError.diskImageFailedSetup }
        
        do {
            let fileHandle = try FileHandle(forWritingTo: url)
            defer { try? fileHandle.close() }
            
            try fileHandle.truncate(atOffset: size)
            
        } catch {
            // A zero-length image left behind would be picked up as "already existing"
            // on the next attempt and attached as an empty disk from then on.
            try? FileManager.default.removeItem(at: url)
            
            throw VZKitError.diskImageFailedSetup
        }
    }
    
    /// This is the static factory method for `VZVirtioBlockDeviceConfiguration`. It creates a block device based
    /// on the input parameters, and returns the attachment to the caller.
    ///
    /// - Parameters:
    ///   - url: The location at which the disk image should be created on the host file system.
    ///   - type: Mounting permissions with integer size of the virtual disk image, in gigabytes.
    static func create(at url: URL, type: MountingOptions) throws -> Product {
        
        let attachment: VZDiskImageStorageDeviceAttachment
        
        let isReadOnly: Bool
        
        switch type {
        case .readOnly(let size):
            try createDiskImage(url, size)
            isReadOnly = true
            
        case .readWrite(let size):
            try createDiskImage(url, size)
            isReadOnly = false
        }
        
        attachment = try VZDiskImageStorageDeviceAttachment(
            url: url,
            readOnly: isReadOnly
        )
        
        return Product(attachment: attachment)
    }
}
