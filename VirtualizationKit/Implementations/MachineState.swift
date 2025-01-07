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
//  MachineState.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 15/05/24.
//

import SwiftUI
import Virtualization

/// A typealias for `VZVirtualMachine.State` that simplifies code readability within the `VirtualizationKit`.
///
/// Using `MachineState` instead of `VZVirtualMachine.State` allows for cleaner code
/// and helps convey the purpose of the state in the context of virtual machine management.
public typealias MachineState = VZVirtualMachine.State

/// Extension on `MachineState` to conform to `VZKitMachineState`, providing color and label representations.
///
/// By conforming `MachineState` to `VZKitMachineState`, this extension defines two methods—`color` and `localized`—
/// that return color and text representations for different states of a virtual machine. This extension simplifies SwiftUI views
/// by allowing the state-based color and label to be retrieved directly from the state, reducing the need for
/// verbose conditional statements in the view code.
extension MachineState: VZKitMachineState {
    
    /// Returns the color associated with the current state of the virtual machine.
    ///
    /// This property provides a color representation based on the state, which can be used in SwiftUI views to indicate
    /// the status of the virtual machine in a visually intuitive way.
    /// For instance, `.green` for `.running` and `.red` for `.stopped`.
    public var color: Color {
        switch self {
        case .starting: .blue
        case .running: .green
        case .restoring: .mint
        case .stopping: .orange
        case .pausing: .orange
        case .paused: .orange
        case .resuming: .orange
        case .saving: .orange
        case .stopped: .red
        case .error: .yellow
        default: .white
        }
    }
    
    /// Returns a localized string representing the current state of the virtual machine.
    ///
    /// This property retrieves a localized string for the virtual machine state, using
    /// localization keys defined in this framework's bundle (`VirtualizationKit.bundle`). It enables
    /// SwiftUI views to display readable, localized text for each state, keeping views cleaner
    /// by eliminating the need for additional localization logic within the view.
    ///
    /// - Localization keys:
    ///   - `vmstate-running`: for `.running` state
    ///   - `vmstate-stopping`: for `.stopping` state
    ///   - `vmstate-stopped`: for `.stopped` state
    ///   - `vmstate-error`: for `.error` state
    ///   - `vmstate-starting`: for `.starting` state
    ///   - `vmstate-paused`: for `.paused` state
    ///   - `vmstate-pausing`: for `.pausing` state
    ///   - `vmstate-resuming`: for `.resuming` state
    ///   - `vmstate-restoring`: for `.restoring` state
    ///   - `vmstate-saving`: for `.saving` state
    ///
    /// If the state does not match any defined case, it defaults to `"undefined-state"`.
    public var localized: String {
        switch self {
        case .running:  VirtualizationKit.localized("vmstate-running")
        case .stopping: VirtualizationKit.localized("vmstate-stopping")
        case .stopped: VirtualizationKit.localized("vmstate-stopped")
        case .error: VirtualizationKit.localized("vmstate-error")
        case .starting: VirtualizationKit.localized("vmstate-starting")
        case .paused: VirtualizationKit.localized("vmstate-paused")
        case .pausing: VirtualizationKit.localized("vmstate-pausing")
        case .resuming: VirtualizationKit.localized("vmstate-resuming")
        case .restoring: VirtualizationKit.localized("vmstate-restoring")
        case .saving: VirtualizationKit.localized("vmstate-saving")
        default: "undefined-state"
        }
    }
}
