//
//  VZKitOperatingSystem.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 16/05/24.
//

import SwiftUI

import UniformTypeIdentifiers

/// VZKitOperatingSystem protocol
///
/// @brief
///    This protocol defines how a Virtual Machine OS Type should be implemented in this application.
///    `VZKitOperatingSystem` helps us define two crucial methods that will significally reduce
///    the bulk of `SwiftUI` statements. We can simply get the assets of the given OS by callin these methods.
public protocol VZKitOperatingSystem: Codable, Hashable, CaseIterable, Sendable {
        
    var image: Image { get }
    
    var label: Text { get }
    
    var fileType: UTType { get }
    
    var version: OperatingSystem.Version? { get }
}
