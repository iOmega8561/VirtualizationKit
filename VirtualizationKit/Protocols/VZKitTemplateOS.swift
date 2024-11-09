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
//  VZKitTemplateOS.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 12/10/24.
//

import SwiftUI

import UniformTypeIdentifiers

/// The `VZKitTemplateOS` protocol defines a structure for storing information
/// about the operating system characteristics of a virtual machine template.
///
/// Conforming types represent essential details about the OS, such as its type,
/// installation requirements, installer source, and associated metadata like
/// display image and label.
///
/// - Conforms to:
///   - `Codable`: Allows encoding and decoding of conforming types.
///   - `Hashable`: Enables the use of conforming types in hashed collections like sets or as dictionary keys.
///   - `Sendable`: Allows safe concurrent access and usage of conforming types across threads.
public protocol VZKitTemplateOS: Codable, Hashable, Sendable {
        
    /// The type of operating system represented by the template.
    var type: OperatingSystem { get }
    
    /// A Boolean value that indicates whether an installation procedure is required
    /// for the operating system. This is typically `true` if the guest is macOS.
    var needsInstall: Bool { get set }
    
    /// The `URL` to the installer file (e.g., `.ISO` or `.IPSW` disk image) for the operating system.
    /// This is `nil` if no installer is available or required.
    var installer: URL? { get set }
    
    /// A graphical representation (icon or thumbnail) associated with the operating system.
    /// The default implementation returns the `image` associated with the `type`.
    var image: Image { get }
    
    /// A text label associated with the operating system for display purposes.
    /// The default implementation returns the `label` associated with the `type`.
    var label: Text { get }
    
    /// The file type identifier (`UTType`) for the OS installer, such as `.iso` or `.ipsw`.
    /// The default implementation returns the `fileType` associated with the `type`.
    var fileType: UTType { get }
}

extension VZKitTemplateOS {
    
    /// Default implementation providing a passthrough from the OS type.
    public var image: Image { type.image }
    
    /// Default implementation providing a passthrough from the OS type.
    public var label: Text { type.label }
    
    /// Default implementation providing a passthrough from the OS type.
    public var fileType: UTType { type.fileType }
}
