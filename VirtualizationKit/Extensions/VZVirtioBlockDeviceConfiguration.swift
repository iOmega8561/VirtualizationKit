//
//  VZVirtioBlockDeviceConfiguration.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 17/05/24.
//

import Virtualization

extension VZVirtioBlockDeviceConfiguration: VZKitPersistentConstructible {    
    
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
        
        guard !FileManager.default.fileExists(
            atPath: url.path(percentEncoded: false)
            
        ) else { return }
        
        FileManager.default.createFile(
            atPath: url.path(percentEncoded: false),
            contents: nil,
            attributes: nil
        )
        
        do {
            try FileHandle(forWritingTo: url).truncate(
                atOffset: size
            )
            
        } catch { throw VZKitError.mainDisk }
    }
    
    /// This is the static factory method for `VZVirtioBlockDeviceConfiguration`. It creates a block device based
    /// on the input parameters, and returns the attachment to the caller.
    ///
    /// - Parameters:
    ///   - url: The location at which the disk image should be created on the host file system.
    ///   - type: Mounting permissions with integer size of the virtual disk image, in gigabytes.
    static func create(at url: URL, type: MountingOptions) throws -> Constructible {
        
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
        
        return Constructible(attachment: attachment)
    }
}
