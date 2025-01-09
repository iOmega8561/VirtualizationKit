//
//  VZKitStorageConstructible.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 09/01/25.
//

protocol VZKitStorageConstructible: VZKitConstructible {
        
    associatedtype InputType
    
    /// This is the standard factory method for any `VZKitStorageConstructible` conforming class.
    /// It creates a block device based on the input parameters, and returns the attachment to the caller.
    ///
    /// - Parameters:
    ///   - url: The location at which the disk image should be created on the host file system.
    ///   - type: Mounting permissions with integer size of the virtual disk image, in gigabytes.
    static func create(at url: URL, type: InputType) throws -> Constructible
}
