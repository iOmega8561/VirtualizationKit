//
//  VZKitTemplateOS.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 12/10/24.
//

import SwiftUI

import UniformTypeIdentifiers

/// The `VZKitTemplateOS` protocol defines a common structure for the information that will be stored inside a template
/// regarding the characteristics of the operating system of a given virtual machine.
public protocol VZKitTemplateOS: Codable, Hashable, Sendable {
        
    /// The Operating System of choice
    var type: OperatingSystem { get }
    
    /// A boolean value that dictates if an installation procedure is needed
    var needsInstall: Bool { get set }
    
    /// The `URL` of the given installer .ISO or .IPSW file (disk image),
    var installer: URL? { get set }
    
    var image: Image { get }
    
    var label: Text { get }
    
    var fileType: UTType { get }
}

extension VZKitTemplateOS {
    
    public var image: Image { type.image }
    
    public var label: Text { type.label }
    
    public var fileType: UTType { type.fileType }
}
