//
//  VZKitRestoreImage.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 13/11/24.
//

import Foundation

/// A protocol defining a restore image for use in virtualization configurations, providing
/// properties and methods to manage macOS restore images in a type-safe and extensible way.
public protocol VZKitRestoreImage {
    
    /// An associated type representing the specific type of restore image that conforms to `VZKitRestoreImage`.
    ///
    /// This type allows implementations to specify their own restore image type, providing flexibility
    /// for different restore image implementations while adhering to the protocol.
    associatedtype ImageType: VZKitRestoreImage
    
    /// An associated type representing the version type of the operating system.
    ///
    /// This type must conform to `VZKitOperatingSystemVersion`, enabling compatibility with different
    /// operating system versions while maintaining a consistent API.
    associatedtype VersionType: VZKitOperatingSystemVersion
    
    /// The version of the operating system associated with the restore image.
    ///
    /// This property provides access to the OS version information, encapsulated within the specified
    /// `VersionType` type. Implementations of this property must return the version of the OS that the
    /// restore image represents.
    var osVersion: VersionType { get }
    
    /// Asynchronously loads a restore image from a specified URL.
    ///
    /// This static function loads the restore image data from a given URL, allowing for asynchronous
    /// handling and error throwing if the load fails. Implementing this function provides a consistent
    /// interface for loading restore images asynchronously across different types of restore images.
    ///
    /// - Parameter url: The URL from which to load the restore image data.
    /// - Returns: An instance of the associated `ImageType` representing the loaded restore image.
    /// - Throws: An error if the image could not be loaded from the specified URL.
    static func load(from url: URL) async throws -> ImageType
}
