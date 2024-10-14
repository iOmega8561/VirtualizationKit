//
//  VZKitOperatingSystem.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 16/05/24.
//

import SwiftUI

import UniformTypeIdentifiers

/// VirtHandlerMachineOS protocol
///
/// @brief
///    This protocol defines how a Virtual Machine OS Type should be implemented in this application.
///    `VirtHandlerMachineOS` helps us define two crucial methods that will significally reduce
///    the bulk of `SwiftUI` statements. We can simply get the assets of the given OS by callin these methods.
public protocol VZKitOperatingSystem: Codable, Hashable, CaseIterable, Sendable {
    
    associatedtype FactoryType: VZKitOperatingSystem
    
    var image: Image { get }
    
    var label: Text { get }
    
    var fileType: UTType { get }
    
    /// Static factory method to create an `VZKitOperatingSystem` conformable object, using information retrieved by
    /// the provided macOS restore image (if present). It allows to manipulate the enum cases to have them store things like OS version.
    ///
    /// - Parameters:
    ///   - expected: The OS type to be expected in return, will probably be blank (no version)
    ///   - url: The URL of the installer image provided by the caller.
    static func createOS(expected: Self, _ url: URL) async throws -> FactoryType
}
