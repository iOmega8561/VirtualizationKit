//
//  VZKitTemplate.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 12/10/24.
//

import Foundation

/// The `VZKitTemplate` protocl defines a common interface for templates to be used with this framework
///
/// @brief
///    The framework relys on the concept of VM Templates. A Template is a simple and concise stored configuration of our VM.
///    Every Template contains only the necessary information for the creation of a VM without carrying all of `Virtualization Framework` bulk.
public protocol VZKitTemplate: Identifiable, Hashable, Sendable, Codable {
    
    associatedtype OperatingSystemType: VZKitTemplateOS
    
    associatedtype TemplateSpecsType: VZKitTemplateSpecs
    
    var timestamp: Date { get }
    
    /// Unique identifier for the model
    var id: UUID { get }
    
    /// The name of the new Virtual Machine
    var name: String { get }
    
    /// The Operating System of choice, properly wrapped as a `VZKitTemplateOS` conforming object
    var os: OperatingSystemType { get }
    
    /// The VM hardware specs, properly wrapped as a `VZKitTemplateSpecs` conforming object.
    var specs: TemplateSpecsType { get }
}
