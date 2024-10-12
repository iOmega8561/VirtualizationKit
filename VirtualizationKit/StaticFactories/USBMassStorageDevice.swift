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
//  USBMassStorageDevice.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 17/05/24.
//

import Virtualization

/// This typealias allows for cleaner-looking code
typealias USBMassStorageDevice = VZUSBMassStorageDeviceConfiguration

/// Protocol conformation of `VZUSBMassStorageDeviceConfiguration` to `VZKitStorageAttachment`
///
/// @brief
///    The `VirtHandlerMachineStorage` protocol allows for a simpler implementation of the static factory method pattern.
///    This extension contains the necessary stubs to achieve conformation and defines an appropriare `CaseIterable`
///    to be used as argument, when calling the factory method.
extension USBMassStorageDevice: VZKitStorageAttachment {
    
    /// MountType `CaseIterable`
    ///
    /// @brief
    ///    When calling the factory method from the outside, this `CaseIterable` becomes very useful
    ///    to provide concise information about read/write mounting permissions.
    enum MountType: CaseIterable {
        case readWrite
        case readOnly
        
        func isReadOnly() -> Bool {
            switch self {
            case .readWrite:
                return false
            case .readOnly:
                return true
            }
        }
    }
    
    /// This method can create a disk image attachment from the host file system.
    /// Useful to simulate optical drives with .ISO files.
    ///
    /// - Parameters:
    ///   - path: The location at which the disk image is located on the host file system.
    ///   - type: The mounting permissions of the disk image.
    static func createDevice(_ path: URL, _ type: MountType) throws -> USBMassStorageDevice {
        
        let attachment = try VZDiskImageStorageDeviceAttachment(
            url: path,
            readOnly: type.isReadOnly()
        )
        
        return USBMassStorageDevice(attachment: attachment)
    }
}
