//
//  MachineIdentifier.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 09/01/25.
//

import Virtualization

/// A protocol representing a machine identifier within the VZKit framework.
///
/// This protocol extends `DataRepresentable` to unify the functionality of various machine identifier types.
/// It allows generic code to handle machine identifiers by providing a standard interface for creation,
/// data serialization, and file-based persistence.
protocol MachineIdentifier: DataRepresentable where Product: MachineIdentifier {
    
    /// Creates a new instance of the machine identifier.
    ///
    /// Use this initializer to create a machine identifier object from scratch,
    /// without relying on any pre-existing data.
    init()
}

extension MachineIdentifier {
    
    /// Creates or retrieves a machine identifier from a file at the specified URL.
    ///
    /// If the file does not exist, this method creates a new machine identifier, serializes it,
    /// and writes it to the specified URL. If the file exists, the method attempts to load and deserialize
    /// the machine identifier from the file.
    ///
    /// - Parameter url: The file URL where the machine identifier is stored or should be created.
    /// - Returns: An instance of the `Constructible` type that conforms to `MachineIdentifier`.
    /// - Throws:
    ///   - `VZKitError.coreFilesMissing` if the file cannot be read or the data is missing.
    ///   - `VZKitError.coreFilesTampered` if the data is invalid or cannot be used to create the object.
    static func create(at url: URL) throws -> Product {
        
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
            let machineId = Product()
            try machineId.dataRepresentation.write(to: url)
            return machineId
        }
    
        return try Self.create(dataAt: url)
    }
}

/// Extends `VZMacMachineIdentifier` to conform to the `MachineIdentifier` protocol.
///
/// This extension enables `VZMacMachineIdentifier` to leverage the default functionality provided
/// by the `MachineIdentifier` protocol, including serialization, deserialization, and file-based persistence.
extension VZMacMachineIdentifier: MachineIdentifier {}

/// Extends `VZGenericMachineIdentifier` to conform to the `MachineIdentifier` protocol.
///
/// This extension enables `VZGenericMachineIdentifier` to leverage the default functionality provided
/// by the `MachineIdentifier` protocol, including serialization, deserialization, and file-based persistence.
extension VZGenericMachineIdentifier: MachineIdentifier {}
