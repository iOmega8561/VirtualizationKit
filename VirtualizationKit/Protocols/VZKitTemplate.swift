//
//  VZKitTemplate.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 12/10/24.
//

import Foundation

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
