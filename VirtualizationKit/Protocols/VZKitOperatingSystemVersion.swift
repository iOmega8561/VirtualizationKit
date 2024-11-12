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
//  VZKitOperatingSystemVersion.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 12/11/24.
//

import Foundation

/// This protocol provides a common interface to create a data structure or class that holds information
/// about the guest operating system version. It requires conformation to several other protocols:
/// - Equatable so that two instances can be compared easily.
/// - Codable is needed so that it can be easily integrated with standard storage systems.
/// - Sendable is useful to silence the Swift compiler. The struct is thread safe.
/// - Hashable so it can be integrated as enum case associated value without complications.
public protocol VZKitOperatingSystemVersion: Codable, Equatable, Sendable, Hashable {
    
    var major: Int { get }
    
    var minor: Int { get }
    
    var patch: Int { get }
    
    /// Static utility method that should return a `VersionType` information, using a macOS restore image.
    ///
    /// - Parameters:
    ///   - url: The URL of the installer image provided by the caller. if the image is not a macOS .ipsw the method should throw
    static func fromImage(withURL url: URL) async throws -> Self
}
