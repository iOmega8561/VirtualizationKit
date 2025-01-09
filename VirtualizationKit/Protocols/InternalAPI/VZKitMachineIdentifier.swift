//
//  VZKitMachineIdentifier.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 09/01/25.
//

import Virtualization

/// This is a utility protocol that help to accomunate the two exisint Virtualization.framework
/// Machine Identifier classes, that are VZMacMachineIdentifier and VZGenericMachineIdentifier.
/// This can be extremely useful to write generic code that can handle both using their common properties.
protocol MachineIdentifier {
    
    /// Explicitly requires the Machine Identifier to be instanciable without any input,
    /// this will be used to create new objects from scratch without reading anything from disk
    init()
    
    /// Explicitly requires the Machine Identifier to be instanciable with input data,
    /// this will be used to create objects based on existing MachineIdentifier data stored on disk
    init?(dataRepresentation: Data)
    
    /// Requires the object to have a data rapresentation property, in order to be able to write it to disk
    var dataRepresentation: Data { get }
}

extension VZMacMachineIdentifier: MachineIdentifier {}

extension VZGenericMachineIdentifier: MachineIdentifier {}
