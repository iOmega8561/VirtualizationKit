//
//  BlockDevice.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 17/05/24.
//

import Virtualization

/// This typealias allows for cleaner-looking code
typealias BlockDevice = VZVirtioBlockDeviceConfiguration

/// Protocol conformation of `VZVirtioBlockDeviceConfiguration` to `VZKitStorageAttachment`
///
/// @brief
///    The `VZKitStorageAttachment` protocol allows for a simpler implementation of the static factory method pattern.
///    This extension contains the necessary stubs to achieve conformation and defines an appropriare `CaseIterable`
///    to be used as argument, when calling the factory method.
extension BlockDevice: VZKitStorageAttachment {
    
    /// MountType `CaseIterable`
    ///
    /// @brief
    ///    When calling the factory method from the outside, this `CaseIterable` becomes very useful
    ///    to provide concise information about disk capacity and read/write mounting permissions.
    enum MountType: CaseIterable {
        public static let allCases: [Self] = [
            .readOnly(size: 0),
            .readWrite(size: 0)
        ]
        
        case readWrite(size: Int)
        case readOnly(size: Int)
    }
    
    /// This method can create a disk image and write it to the host file system.
    /// If a disk image already exists at the given location, it simply returns.
    ///
    /// - Parameters:
    ///   - path: The location at which the disk image should be created on the host file system.
    ///   - size: The integer size of the virtual disk image, in gigabytes.
    static private func createDiskImage(_ path: String, _ size: Int) throws {
        
        guard !FileManager.default.fileExists(atPath: path) else {
            return
        }
        
        do {
            FileManager.default.createFile(
                atPath: path,
                contents: nil,
                attributes: nil
            )
            
            let handle = try FileHandle(forWritingTo: URL(filePath: path))
            try handle.truncate(atOffset: UInt64(size * 1024 * 1024 * 1024))
        } catch {
            throw VZKitError.mainDisk
        }
    }
    
    /// This is the static factory method for `VZVirtioBlockDeviceConfiguration`. It creates a block device based
    /// on the input parameters, and returns the attachment to the caller.
    ///
    /// - Parameters:
    ///   - path: The location at which the disk image should be created on the host file system.
    ///   - type: Mounting permissions with integer size of the virtual disk image, in gigabytes.
    static func createDevice(_ path: String, _ type: MountType) throws -> BlockDevice {
        
        let attachment: VZDiskImageStorageDeviceAttachment
        
        switch type {
        case .readOnly(let size):
            
            try createDiskImage(path, size)
            
            attachment = try VZDiskImageStorageDeviceAttachment(
                url: URL(filePath: path),
                readOnly: true
            )
                        
        case .readWrite(let size):
            
            try createDiskImage(path, size)
            
            attachment = try VZDiskImageStorageDeviceAttachment(
                url: URL(filePath: path),
                readOnly: false
            )
        }
        
        return BlockDevice(attachment: attachment)
    }
}
