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
//  OperatingSystem.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 16/05/24.
//

import SwiftUI

import Virtualization

import UniformTypeIdentifiers

/// The `OperatingSystem` enum specifies the supported operating systems for virtual machines
/// within VirtualizationKit. Reflecting the capabilities of the currently implemented virtualization
/// backends, it currently supports only Linux and macOS.
///
/// Each case is associated with a set of metadata that defines its display name, logo image, expected
/// disk image file type, and, for macOS, an optional OS version. These metadata properties are exposed
/// via dedicated computed properties, allowing UI components and file handlers to easily access this
/// information without revealing the underlying implementation details.
///
/// Conformance to `VZKitTransferable` ensures seamless integration with other components in VirtualizationKit.
///
/// ### Usage Example
/// ```swift
/// let os: OperatingSystem = .macos(version: someVersion)
/// print(os.displayName)  // "macOS"
/// print(os.logoImage)    // Displays the Apple logo image
/// print(os.fileType)     // The disk image file type expected for macOS
/// ```
///
/// You can also initialize an instance from a disk image URL:
/// ```swift
/// do {
///     let detectedOS = try await OperatingSystem(fromImageAt: imageURL)
///     // Proceed with the detected macOS operating system
/// } catch {
///     // Handle error: the URL did not point to a valid macOS Restore Image
/// }
/// ```
public enum OperatingSystem: VZKitTransferable {
    
    /// Encapsulates display and file metadata for an operating system.
    private struct MetaData {
        /// The name to display in the UI.
        let displayName: String
        /// The logo image representing the operating system.
        let logoImage: Image
        /// The expected disk image file type.
        let fileType: UTType
        /// The operating system version, if applicable.
        let version: Version?
    }
    
    /// Represents a Linux-based virtual machine.
    case linux
    
    /// Represents a macOS virtual machine.
    ///
    /// - Parameter version: The macOS version associated with the virtual machine. Defaults to the
    ///   minimum supported version defined in VirtualizationKit.
    case macos(version: Version = VirtualizationKit.macOSGuestMinVersion)
    
    /// Provides the associated metadata for the operating system case.
    private var metaData: MetaData {
        switch self {
        case .linux: .init(
            displayName: "Linux",
            logoImage: .init("tux", bundle: VirtualizationKit.bundle),
            fileType: .diskImage,
            version: nil
        )
        case .macos(let version): .init(
            displayName: "macOS",
            logoImage: .init(systemName: "apple.logo"),
            fileType: .init(filenameExtension: "ipsw")!,
            version: version
        )}
    }
    
    /// The display name of the operating system.
    public var displayName: String { metaData.displayName }
    
    /// The logo image associated with the operating system.
    public var logoImage: Image { metaData.logoImage }
    
    /// The expected disk image file type for the operating system.
    public var fileType: UTType { metaData.fileType }
    
    /// The operating system version, if applicable.
    public var version: Version? { metaData.version }
    
    /// Asynchronously initializes an `OperatingSystem` from a disk image URL.
    ///
    /// This initializer attempts to load a macOS IPSW Restore Image from the provided URL. If successful,
    /// it infers a macOS operating system and extracts its version information. If the URL does not point
    /// to a valid macOS Restore Image, the initialization throws the underlying error.
    ///
    /// - Parameter location: The URL of the IPSW restore image used to detect the macOS version.
    public init(fromImageAt location: URL) async throws {
        
        let macOSRestoreImage = try await VZMacOSRestoreImage.load(
            from: location
        )
        self = .macos(
            version: .init(macOSRestoreImage.operatingSystemVersion)
        )
    }
}
