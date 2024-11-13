//
//  VZKitStorageAttachment.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 17/05/24.
//

import Virtualization

/// VZKitStorageAttachment protocol
///
/// @brief
///    This protocol defines how a Virtual Machine storage device should be implemented in this application.
///    The static method "createDevice" resembles a factory pattern.
protocol VZKitStorageAttachment {
    
    associatedtype DeviceType: VZKitStorageAttachment
        
    associatedtype InputType: CaseIterable
    
    /// This is the static, standard factory method for any `VZKitStorageAttachment` conforming class.
    /// It creates a block device based on the input parameters, and returns the attachment to the caller.
    ///
    /// - Parameters:
    ///   - url: The location at which the disk image should be created on the host file system.
    ///   - type: Mounting permissions with integer size of the virtual disk image, in gigabytes.
    static func createDevice(_ url: URL, _ type: InputType) throws -> DeviceType
}
