//
//  VirtualMachineState.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 15/05/24.
//

import SwiftUI
import Virtualization

/// A typealias for `VZVirtualMachine.State` that simplifies code readability within the `VirtualizationKit`.
///
/// Using `VirtualMachineState` instead of `VZVirtualMachine.State` allows for cleaner code
/// and helps convey the purpose of the state in the context of virtual machine management.
public typealias VirtualMachineState = VZVirtualMachine.State

/// Extension on `VirtualMachineState` to conform to `VZKitMachineState`, providing color and label representations.
///
/// By conforming `VirtualMachineState` to `VZKitMachineState`, this extension defines two methods—`color` and `localized`—
/// that return color and text representations for different states of a virtual machine. This extension simplifies SwiftUI views
/// by allowing the state-based color and label to be retrieved directly from the state, reducing the need for
/// verbose conditional statements in the view code.
extension VirtualMachineState: VZKitMachineState {
    
    /// Returns the color associated with the current state of the virtual machine.
    ///
    /// This property provides a color representation based on the state, which can be used in SwiftUI views to indicate
    /// the status of the virtual machine in a visually intuitive way.
    /// For instance, `.green` for `.running` and `.red` for `.stopped`.
    public var color: Color {
        switch self {
        case .running:
            return .green
            
        case .stopping:
            return .orange
            
        case .stopped:
            return .red
            
        case .error:
            return .yellow
        
        case .starting:
            return .blue
            
        case .pausing:
            return .orange
            
        case .paused:
            return .orange
        
        case .resuming:
            return .orange
        
        case .restoring:
            return .mint
            
        default:
            return .white
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
    ///   - `details-vmstate-running`: for `.running` state
    ///   - `details-vmstate-stopping`: for `.stopping` state
    ///   - `details-vmstate-stopped`: for `.stopped` state
    ///   - `details-vmstate-error`: for `.error` state
    ///   - `details-vmstate-starting`: for `.starting` state
    ///   - `details-vmstate-paused`: for `.paused` state
    ///   - `details-vmstate-pausing`: for `.pausing` state
    ///   - `details-vmstate-resuming`: for `.resuming` state
    ///   - `details-vmstate-restoring`: for `.restoring` state
    ///
    /// If the state does not match any defined case, it defaults to `"default-state"`.
    public var localized: String {
        switch self {
        case .running:
            return String(
                localized: "details-vmstate-running",
                bundle: VirtualizationKit.bundle
            )
            
        case .stopping:
            return String(
                localized: "details-vmstate-stopping",
                bundle: VirtualizationKit.bundle
            )
            
        case .stopped:
            return String(
                localized: "details-vmstate-stopped",
                bundle: VirtualizationKit.bundle
            )
        
        case .error:
            return String(
                localized: "details-vmstate-error",
                bundle: VirtualizationKit.bundle
            )
        
        case .starting:
            return String(
                localized: "details-vmstate-starting",
                bundle: VirtualizationKit.bundle
            )
        
        case .paused:
            return String(
                localized: "details-vmstate-paused",
                bundle: VirtualizationKit.bundle
            )
        
        case .pausing:
            return String(
                localized: "details-vmstate-pausing",
                bundle: VirtualizationKit.bundle
            )
            
        case .resuming:
            return String(
                localized: "details-vmstate-resuming",
                bundle: VirtualizationKit.bundle
            )
        
        case .restoring:
            return String(
                localized: "details-vmstate-restoring",
                bundle: VirtualizationKit.bundle
            )
               
        default:
            return String("default-state")
        }
    }
}
