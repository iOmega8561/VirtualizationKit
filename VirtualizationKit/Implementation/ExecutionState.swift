//
//  ExecutionState.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 20/01/25.
//

import SwiftUI

import Virtualization

/// An enumeration describing the various states a virtual machine can be in.
///
/// This enum provides additional information such as color indicators and localized strings to better integrate
/// with SwiftUI views and localization mechanisms. Although it conforms to RawRepresentable using Int, the enum
/// provides .error and .installing that have associated values. This allows to centralize observation of everything
/// that is going on with the virtual machine by using ExecutionState.
public enum ExecutionState: RawRepresentable, VZKitTransferable {
    
    public typealias RawValue = Int
    
    /// The virtual machine has stopped.
    case stopped
    
    /// The virtual machine is fully running.
    case running
    
    /// The virtual machine is paused.
    case paused
    
    /// The virtual machine is in an error state.
    case error(error: Error)
    
    /// The virtual machine is in the process of starting.
    case starting
    
    /// The virtual machine is in the process of pausing.
    case pausing
    
    /// The virtual machine is in the process of resuming from a paused state.
    case resuming
    
    /// The virtual machine is in the process of stopping.
    case stopping
    
    /// The virtual machine is saving its current state.
    case saving
    
    /// The virtual machine is restoring from a saved state.
    case restoring
    
    /// The virtual machine is in the process of being installed.
    case installing(progress: Double)
    
    /// Returns the color associated with the current state of the virtual machine.
    ///
    /// Use this property in SwiftUI views to visually indicate the status of
    /// the virtual machine. For example:
    /// - `.green` for `.running`
    /// - `.red` for `.stopped`
    /// - `.orange` for `.starting`
    /// - Note: In general if the color is .orange it means that it is a transition state
    public var color: Color {
        switch self {
        case .stopped: .red
        case .running: .green
        case .paused: .orange
        case .error: .yellow
        case .starting: .orange
        case .pausing: .orange
        case .resuming: .orange
        case .stopping: .orange
        case .saving: .orange
        case .restoring: .orange
        case .installing: .mint
        }
    }
    
    /// Returns a localized string representing the current state of the virtual machine.
    ///
    /// This property retrieves a localized string for the virtual machine state, using
    /// localization keys defined in this framework's bundle (`VirtualizationKit.bundle`).
    /// This helps SwiftUI views display readable, localized text for each state, keeping views
    /// cleaner by removing the need for additional localization logic.
    ///
    /// - Localization keys:
    ///   - `vmstate-installing`: for `.installing`
    ///   - `vmstate-running`: for `.running`
    ///   - `vmstate-stopping`: for `.stopping`
    ///   - `vmstate-stopped`: for `.stopped`
    ///   - `vmstate-error`: for `.error`
    ///   - `vmstate-starting`: for `.starting`
    ///   - `vmstate-paused`: for `.paused`
    ///   - `vmstate-pausing`: for `.pausing`
    ///   - `vmstate-resuming`: for `.resuming`
    ///   - `vmstate-restoring`: for `.restoring`
    ///   - `vmstate-saving`: for `.saving`
    public var localized: String {
        switch self {
        case .stopped: VZKitLocale("vmstate-stopped").value
        case .running: VZKitLocale("vmstate-running").value
        case .paused: VZKitLocale("vmstate-paused").value
        case .error: VZKitLocale("vmstate-error").value
        case .starting: VZKitLocale("vmstate-starting").value
        case .pausing: VZKitLocale("vmstate-pausing").value
        case .resuming: VZKitLocale("vmstate-resuming").value
        case .stopping: VZKitLocale("vmstate-stopping").value
        case .saving: VZKitLocale("vmstate-saving").value
        case .restoring: VZKitLocale("vmstate-restoring").value
        case .installing: VZKitLocale("vmstate-installing").value
        }
    }

    public var rawValue: RawValue {
        switch self {
        case .stopped: 0
        case .running: 1
        case .paused: 2
        case .error: 3
        case .starting: 4
        case .pausing: 5
        case .resuming: 6
        case .stopping: 7
        case .saving: 8
        case .restoring: 9
        case .installing: 10
        }
    }
    
    public init?(rawValue: RawValue) {
        switch rawValue {
        case 0: self = .stopped
        case 1: self = .running
        case 2: self = .paused
        case 4: self = .starting
        case 5: self = .pausing
        case 6: self = .resuming
        case 7: self = .stopping
        case 8: self = .saving
        case 9: self = .restoring
        default: return nil
        }
    }
    
    init?(_ vzState: VZVirtualMachine.State) {
        self.init(rawValue: vzState.rawValue)
    }
}
