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
    /// The `Version` struct provides a consistent and structured way to store version information, including:
    /// - Major version number
    /// - Minor version number (optional)
    /// - Patch version number (optional)
    /// - Build identifier (optional)
    ///
    /// ## Features
    /// The `Version` struct conforms to several protocols, enhancing its functionality and interoperability:
    /// - `Equatable`: Enables comparison of two `Version` instances for equality.
    /// - `Codable`: Allows seamless encoding and decoding, making it compatible with serialization formats like JSON.
    /// - `Sendable`: Ensures thread safety for use in concurrent contexts.
    /// - `Hashable`: Facilitates use as keys in dictionaries or as elements in sets.
    /// - `Comparable`: Enables relational comparisons between `Version` instances.
    ///
    /// ## Use Cases
    /// This struct is ideal for:
    /// - Representing and comparing OS versions.
    /// - Encoding/decoding version information in distributed systems.
    /// - Tracking software builds with a combination of version numbers and build identifiers.
    ///
    /// ## Utility
    /// The `Version` struct includes a static utility method to create instances based on macOS restore images,
    /// making it particularly useful in virtualization and deployment scenarios.
    ///
    /// - Note: When using `Comparable`, versions are compared by their major, minor, patch, and build values in sequence.
    public struct Version: Equatable, Comparable, VZKitTransferable {
        
        // MARK: - Comparable Conformance
            
        /// Compares two `Version` instances to determine if the left-hand instance is less than the right-hand instance.
        ///
        /// - Parameters:
        ///   - lhs: The left-hand `Version` instance.
        ///   - rhs: The right-hand `Version` instance.
        /// - Returns: `true` if the left-hand version is less than the right-hand version, otherwise `false`.
        public static func < (lhs: Version, rhs: Version) -> Bool {
            
            if lhs.major != rhs.major {
                lhs.major < rhs.major
                
            } else if let lhsMinor = lhs.minor,
                      let rhsMinor = rhs.minor,
                      lhsMinor != rhsMinor {
                lhsMinor < rhsMinor
                
            } else if let lhsPatch = lhs.patch,
                      let rhsPatch = rhs.patch,
                      lhsPatch != rhsPatch {
                lhsPatch < rhsPatch
                
            } else if let lhsBuild = lhs.build,
                      let rhsBuild = rhs.build,
                      lhsBuild != rhsBuild {
                
                lhsBuild < rhsBuild
                
            } else { lhs.major < rhs.major }
        }
        
        // MARK: - Properties
        
        /// The major version number of the operating system.
        public let major: Int
        
        /// The minor version number of the operating system, if available.
        public let minor: Int?
        
        /// The patch version number of the operating system, if available.
        public let patch: Int?
        
        /// The build identifier string of the operating system, if available.
        public let build: String?
        
        /// A textual representation of the version and build identifier.
        ///
        /// This property combines the major, minor, and patch numbers along with the build string (if available)
        /// into a single descriptive string.
        ///
        /// - Example:
        ///   - `Version(major: 12, minor: 3, patch: 1, build: "21E258").description`
        ///   produces `"12.3.1 (21E258)"`
        public var description: String {
            var version = "\(major)"
            if let minor = self.minor { version += ".\(minor)" }
            if let patch = self.patch { version += ".\(patch)" }
            if let build = self.build { version += " (\(build))" }
            return version
        }
        
        // MARK: - Initializers
        
        /// Initializes a `Version` instance with specific major, minor, patch, and build values.
        ///
        /// - Parameters:
        ///   - major: The major version number.
        ///   - minor: The minor version number, if applicable.
        ///   - patch: The patch version number, if applicable.
        ///   - build: The build identifier string, if applicable.
        public init(major: Int, minor: Int? = nil, patch: Int? = nil, build: String? = nil) {
            self.major = major
            self.minor = minor
            self.patch = patch
            self.build = build
        }
        
        /// Initializes a `Version` instance from an `OperatingSystemVersion` object.
        ///
        /// - Parameters:
        ///   - version: An `OperatingSystemVersion` object representing the OS version.
        ///   - build: An optional build identifier string.
        init(_ version: OperatingSystemVersion, _ build: String? = nil) {
            self.major = version.majorVersion
            self.minor = version.minorVersion
            self.patch = version.patchVersion
            self.build = build
        }
    }
}
