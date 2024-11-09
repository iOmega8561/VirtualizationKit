//
//  Copyright (C) Giuseppe Rocco - All Rights Reserved
//  Unauthorized copying, modification or distribution of this source code,
//  via any medium is strictly prohibited and penally persecutable
//
//  This project and its source code are PROPRIETARY AND CONFIDENTIAL
//  Written by Giuseppe Rocco <giusepperocco38@gmail.com>, May 2024
//
//  -----------------------------------------------------------------------
//
//  VZKitMachineState.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 29/04/24.
//

import SwiftUI

/// The `VZKitMachineState` protocol defines a standard interface for representing and managing
/// the display attributes of a virtual machine's execution state within the application.
///
/// Conforming to `VZKitMachineState` requires an implementation to provide a color and a localized
/// description for each state. These properties simplify the integration of execution state
/// information in SwiftUI views, allowing for cleaner, more readable UI code by reducing the need
/// for repetitive conditionals or formatting logic within the view layer.
public protocol VZKitMachineState {
    
    /// A color associated with the current execution state of the virtual machine.
    ///
    /// This color can be used in SwiftUI views to visually represent the virtual machine's state.
    /// For example, a `.running` state might return `.green`, while a `.stopped` state might return `.red`.
    /// Using a standardized color for each state enhances UI consistency and improves user experience.
    var color: Color { get }
    
    /// A localized string representing the current execution state of the virtual machine.
    ///
    /// This string provides a human-readable, localized description of the virtual machine's state.
    /// It can be displayed in SwiftUI views to give users contextual information about the virtual machine.
    /// Localization support ensures that this description is accessible in multiple languages,
    /// improving internationalization and user comprehension.
    var localized: String { get }
}
