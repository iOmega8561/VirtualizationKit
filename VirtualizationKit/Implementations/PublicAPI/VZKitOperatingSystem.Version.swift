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
//  VZKitOperatingSystem.Version.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 12/11/24.
//

import Virtualization

extension VZKitOperatingSystem {
    
    /// A data structure that standardizes the representation of a guest operating system version.
    ///
    /// The `Version` struct provides a consistent and structured way to store version information, including major, minor,
    /// and patch version numbers. It conforms to several protocols to enhance its functionality and compatibility:
    /// - `Equatable`: Allows for easy comparison of two `Version` instances.
    /// - `Codable`: Enables seamless integration with encoding and decoding systems, such as JSON or property lists.
    /// - `Sendable`: Ensures thread safety, allowing instances to be used across concurrent contexts without issue.
    /// - `Hashable`: Facilitates use as an associated value in enums and in collections like dictionaries and sets.
    ///
    /// This struct also includes a static utility method to retrieve a `Version` instance based on a macOS restore image,
    /// enabling streamlined extraction of version information from provided image files.
    public struct Version: Equatable, Codable, Sendable, Hashable {
        
        /// The major version number of the operating system.
        public let major: Int
        
        /// The minor version number of the operating system.
        public let minor: Int?
        
        /// The patch version number of the operating system.
        public let patch: Int?
        
        /// The build identifier string of the operating system
        public let build: String?
        
        /// The full qualified version & build description of the operating system
        public var description: String {
            var version = "\(major)"
            
            if let minor = self.minor { version += ".\(minor)" }
            if let patch = self.patch { version += ".\(patch)" }
            if let build = self.build { version += " (\(build))" }
            
            return version
        }
        
        /// Initializes a `Version` instance with specific major, minor, and patch version numbers.
        ///
        /// - Parameters:
        ///   - major: The major version number.
        ///   - minor: The minor version number, if applicable.
        ///   - patch: The patch version number, if applicable.
        ///   - build: The build version string, if applicable.
        public init(major: Int, minor: Int? = nil, patch: Int? = nil, build: String? = nil) {
            self.major = major
            self.minor = minor
            self.patch = patch
            self.build = build
        }
        
        /// Initializes a `Version` instance from an `OperatingSystemVersion` object.
        ///
        /// - Parameter version: An `OperatingSystemVersion` instance from which to derive the `Version` instance.
        init(_ version: OperatingSystemVersion, _ build: String? = nil) {
            self.major = version.majorVersion
            self.minor = version.minorVersion
            self.patch = version.patchVersion
            self.build = build
        }
    }
    
}
