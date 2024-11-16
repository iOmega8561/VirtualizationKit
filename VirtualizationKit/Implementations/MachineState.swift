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
    /// If the state does not match any defined case, it defaults to `"undefined-state"`.
    public var localized: String {
        switch self {
        case .running:
            return VirtualizationKit.localized("vmstate-running")
            
        case .stopping:
            return VirtualizationKit.localized("vmstate-stopping")
            
        case .stopped:
            return VirtualizationKit.localized("vmstate-stopped")
        
        case .error:
            return VirtualizationKit.localized("vmstate-error")
        
        case .starting:
            return VirtualizationKit.localized("vmstate-starting")
        
        case .paused:
            return VirtualizationKit.localized("vmstate-paused")
        
        case .pausing:
            return VirtualizationKit.localized("vmstate-pausing")
            
        case .resuming:
            return VirtualizationKit.localized("vmstate-resuming")
        
        case .restoring:
            return VirtualizationKit.localized("vmstate-restoring")
               
        default:
            return "undefined-state"
        }
    }
}
