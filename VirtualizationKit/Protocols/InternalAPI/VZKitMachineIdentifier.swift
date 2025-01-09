//
//  VZKitMachineIdentifier.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 09/01/25.
//

import Virtualization

/// A utility protocol that unifies the functionality of `VZMacMachineIdentifier`
/// and `VZGenericMachineIdentifier`.
///
/// This protocol allows generic code to work with both classes by exposing common
/// properties and initialization methods. It is particularly useful when handling
/// identifiers in the Virtualization framework.
protocol MachineIdentifier {
    
    /// Creates a new instance of the machine identifier.
    ///
    /// This initializer is used to create new machine identifier objects from scratch,
    /// without relying on any pre-existing data.
    init()
    
    /// Creates a new instance of the machine identifier from existing data.
    ///
    /// This initializer is used to create machine identifier objects based on data
    /// that has been previously stored, such as when reading from disk.
    ///
    /// - Parameter dataRepresentation: A data representation of the machine identifier.
    init?(dataRepresentation: Data)
    
    /// A data representation of the machine identifier.
    ///
    /// This property provides a way to serialize the machine identifier for storage,
    /// such as writing it to a file on disk.
    var dataRepresentation: Data { get }
}

/// Extends `VZMacMachineIdentifier` to conform to the `MachineIdentifier` protocol.
extension VZMacMachineIdentifier: MachineIdentifier {}

/// Extends `VZGenericMachineIdentifier` to conform to the `MachineIdentifier` protocol.
extension VZGenericMachineIdentifier: MachineIdentifier {}
