//
//  VZVirtualMachine.State.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 15/05/24.
//

import SwiftUI

import Virtualization

/// Extension on `VZVirtualMachine.State` providing color and label representations.
///
/// This extension defines two methods—`color` and `localized`—
/// that return color and text representations for different states of a virtual machine. This extension simplifies SwiftUI views
/// by allowing the state-based color and label to be retrieved directly from the state, reducing the need for
/// verbose conditional statements in the view code.
extension VZVirtualMachine.State {
    
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
        case .running:  VZKitLocale("vmstate-running").value
        case .stopping: VZKitLocale("vmstate-stopping").value
        case .stopped: VZKitLocale("vmstate-stopped").value
        case .error: VZKitLocale("vmstate-error").value
        case .starting: VZKitLocale("vmstate-starting").value
        case .paused: VZKitLocale("vmstate-paused").value
        case .pausing: VZKitLocale("vmstate-pausing").value
        case .resuming: VZKitLocale("vmstate-resuming").value
        case .restoring: VZKitLocale("vmstate-restoring").value
        case .saving: VZKitLocale("vmstate-saving").value
        default: "undefined-state"
        }
    }
}
