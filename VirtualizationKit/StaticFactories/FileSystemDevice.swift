//
//  FileSystemDevice.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 17/05/24.
//

import Virtualization

///This typealias allows for cleaner-looking code
typealias FileSystemDevice = VZVirtioFileSystemDeviceConfiguration

/// Protocol conformation of `VZVirtioFileSystemDeviceConfiguration` to `VZKitStorageAttachment`
///
/// @brief
///    The `VZKitStorageAttachment` protocol allows for a simpler implementation of the static factory method pattern.
///    This extension contains the necessary stubs to achieve conformation.
extension FileSystemDevice: VZKitStorageAttachment {
    
    /// This method can create a shared directory mount between the host and the guest systems.
    /// Sets the appropriate tag depending on the chosen guest operating system, for example to support
    /// auto-mounting features on macOS guests, and returns the attachment to the caller.
    ///
    /// - Parameters:
    ///   - url: The location at which the shared mount should be created on the host file system.
    ///   - type: The guest operating system.
    static func createDevice(_ url: URL, _ type: OperatingSystem) throws -> FileSystemDevice {
        
        try FileManager.default.createDirectory(
            atPath: url.path(percentEncoded: false),
            withIntermediateDirectories: true
        )
        
        let sharedDirectory = VZSharedDirectory(
            url: url,
            readOnly: false
        )
        
        let singleDirectoryShare = VZSingleDirectoryShare(directory: sharedDirectory)
        
        let sharingDevice: FileSystemDevice
        
        switch type {
        case .macos(let version):
            
            guard version.major > 12 else {
                throw VZKitError.guestFeatureNotSupported("VZDirectoryShare")
            }
            
            sharingDevice = FileSystemDevice(
                tag: FileSystemDevice.macOSGuestAutomountTag
            )
            
        default:
            sharingDevice = FileSystemDevice(tag: "DEFAULT_SHARE")
            
        }
        
        sharingDevice.share = singleDirectoryShare
        
        return sharingDevice
    }
}
