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
//  OperatingSystem.Version.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 12/11/24.
//

import Virtualization

extension OperatingSystem {
    
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
    public struct Version: VZKitOperatingSystemVersion {
        
        /// Asynchronously retrieves a `Version` instance from a specified macOS restore image URL.
        ///
        /// This method loads a macOS restore image from the provided URL, then extracts version information
        /// if the image is valid. If the image is not a macOS `.ipsw` file, or if loading fails, the method will throw an error.
        ///
        /// - Parameter url: The URL of the macOS installer image file. This should be an `.ipsw` image to parse successfully.
        /// - Returns: A `Version` instance containing the parsed version information from the restore image.
        /// - Throws: An error if the restore image could not be loaded or is invalid.
        public static func fromImage(withURL url: URL) async throws -> Self {
            
            return try await VZMacOSRestoreImage.load(from: url).osVersion
        }
        
        /// The major version number of the operating system.
        public let major: Int
        
        /// The minor version number of the operating system.
        public let minor: Int
        
        /// The patch version number of the operating system.
        public let patch: Int
        
        /// Initializes a `Version` instance with specific major, minor, and patch version numbers.
        ///
        /// - Parameters:
        ///   - major: The major version number.
        ///   - minor: The minor version number.
        ///   - patch: The patch version number.
        public init(major: Int, minor: Int, patch: Int) {
            self.major = major
            self.minor = minor
            self.patch = patch
        }
        
        /// Initializes a `Version` instance from an `OperatingSystemVersion` object.
        ///
        /// - Parameter version: An `OperatingSystemVersion` instance from which to derive the `Version` instance.
        public init(_ version: OperatingSystemVersion) {
            self.major = version.majorVersion
            self.minor = version.minorVersion
            self.patch = version.patchVersion
        }
    }
    
}
