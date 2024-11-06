//
//  VZKitMachineState.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 29/04/24.
//

import SwiftUI

/// VZKitMachineState protocol
///
/// @brief
///    This protocol defines how a Virtual Machine state enumeration should be implemented in this application.
///    `VZKitMachineState` helps us define two crucial methods that will significally reduce the bulk of `SwiftUI` statements.
public protocol VZKitMachineState {
    
    var color: Color { get }
    
    var localized: String { get }
}
