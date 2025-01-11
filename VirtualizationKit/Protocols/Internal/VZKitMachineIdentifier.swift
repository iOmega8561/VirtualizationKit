//
//  VZKitMachineIdentifier.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 09/01/25.
//

import Virtualization

/// A protocol representing a machine identifier within the VZKit framework.
///
/// This protocol extends `VZKitDataRepresentable` to unify the functionality of various machine identifier types.
/// It allows generic code to handle machine identifiers by providing a standard interface for creation,
/// data serialization, and file-based persistence.
protocol VZKitMachineIdentifier: VZKitDataRepresentable where Constructible: VZKitMachineIdentifier {
    
    /// Creates a new instance of the machine identifier.
    ///
    /// Use this initializer to create a machine identifier object from scratch,
    /// without relying on any pre-existing data.
    init()
}

extension VZKitMachineIdentifier {
    
    /// Creates or retrieves a machine identifier from a file at the specified URL.
    ///
    /// If the file does not exist, this method creates a new machine identifier, serializes it,
    /// and writes it to the specified URL. If the file exists, the method attempts to load and deserialize
    /// the machine identifier from the file.
    ///
    /// - Parameter url: The file URL where the machine identifier is stored or should be created.
    /// - Returns: An instance of the `Constructible` type that conforms to `VZKitMachineIdentifier`.
    /// - Throws:
    ///   - `VZKitError.coreFilesMissing` if the file cannot be read or the data is missing.
    ///   - `VZKitError.coreFilesTampered` if the data is invalid or cannot be used to create the object.
    static func create(at url: URL) throws -> Constructible {
        
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
            let machineId = Constructible()
            try machineId.dataRepresentation.write(to: url)
            return machineId
        }
        
        let data = try Self.create(dataAt: url)
        
        return data
    }
}

/// Extends `VZMacMachineIdentifier` to conform to the `VZKitMachineIdentifier` protocol.
///
/// This extension enables `VZMacMachineIdentifier` to leverage the default functionality provided
/// by the `VZKitMachineIdentifier` protocol, including serialization, deserialization, and file-based persistence.
extension VZMacMachineIdentifier: VZKitMachineIdentifier {}

/// Extends `VZGenericMachineIdentifier` to conform to the `VZKitMachineIdentifier` protocol.
///
/// This extension enables `VZGenericMachineIdentifier` to leverage the default functionality provided
/// by the `VZKitMachineIdentifier` protocol, including serialization, deserialization, and file-based persistence.
extension VZGenericMachineIdentifier: VZKitMachineIdentifier {}
