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

/// This enumeration has been created to define the possible operating systems that can be associated to a virtual machine.
/// Since Apple Virtualization Framework officially supports only Linux and macOS, only these two are included.
public enum OperatingSystem: VZKitOperatingSystem {
        
    /// Conformation to `CaseIterable`
    public static let allCases: [Self] = [
        .linux,
        .macos()
    ]
    
    /// Standard case for Linux virtual machines
    case linux
    
    /// Standard case for macOS virtual machines, defaults with minimum supported version
    case macos(version: Version = VirtualizationKit.macOSGuestMinVersion)
    
    /// An image representing the operating system.
    ///
    /// - Returns:
    ///   - For `.linux`, returns an image named "tux" from the `VirtualizationKit` bundle, symbolizing Linux.
    ///   - For `.macos`, returns a system image with the "apple.logo" symbol, representing macOS.
    public var image: Image {
        switch self {
        case .linux:
            return Image("tux", bundle: VirtualizationKit.bundle)
            
        case .macos:
            return Image(systemName: "apple.logo")
        }
    }
    
    /// A text label for the operating system.
    ///
    /// - Returns:
    ///   - For `.linux`, returns a `Text` object with the label "Linux".
    ///   - For `.macos`, returns a `Text` object with the label "macOS".
    public var label: Text {
        switch self {
        case .linux:
            return Text(verbatim: "Linux")
            
        case .macos:
            return Text(verbatim: "macOS")
        }
    }
    
    /// The file type associated with the operating system’s disk image or package.
    ///
    /// - Returns:
    ///   - For `.linux`, returns `.diskImage`, indicating a standard disk image format.
    ///   - For `.macos`, returns a `UTType` for files with the "ipsw" extension, commonly used for macOS firmware packages.
    public var fileType: UTType {
        switch self {
        case .linux:
            return .diskImage
            
        case .macos:
            return UTType(filenameExtension: "ipsw")!
        }
    }
    
    /// The version of the operating system, if available.
    ///
    /// - Returns:
    ///   - For `.linux`, returns `nil` as no version information is required.
    ///   - For `.macos`, returns the specified `Version` instance, indicating the macOS version.
    public var version: Version? {
        switch self {
        case .linux:
            return nil
            
        case .macos(let version):
            return version
        }
    }
}
