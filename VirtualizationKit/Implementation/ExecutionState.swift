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
/// This enum provides detailed information about the current status of a virtual machine, including
/// visual cues and localized descriptions to integrate seamlessly with SwiftUI and localization systems.
/// It conforms to `RawRepresentable` using `Int` as the raw value, while also allowing for associated
/// values for more complex states like `.error` and `.installing`.
///
/// The primary use case for this enum is to centralize and observe the state transitions of a virtual
/// machine, providing a consistent way to track and display its status in a user interface.
public enum ExecutionState: RawRepresentable, Transferable {
    
    // MARK: - RawValue
    
    /// The raw value type for `ExecutionState`.
    public typealias RawValue = Int
    
    // MARK: - Custom Comparable
    
    /// Compares two `ExecutionState` instances for equality.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand `ExecutionState` to compare.
    ///   - rhs: The right-hand `ExecutionState` to compare.
    /// - Returns: A Boolean value indicating whether the two states are equal.
    public static func == (lhs: ExecutionState, rhs: ExecutionState) -> Bool {
        switch (lhs, rhs) {
        case let (.installing(lhsProgress), .installing(rhsProgress)):
            return lhsProgress == rhsProgress
        case let (.error(lhsError), .error(rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return lhs.rawValue == rhs.rawValue
        }
    }
    
    // MARK: - Cases
    
    /// The virtual machine has stopped.
    case stopped
    
    /// The virtual machine is fully running.
    case running
    
    /// The virtual machine is paused.
    case paused
    
    /// The virtual machine is in an error state.
    ///
    /// - Parameter error: The associated error providing details about the issue.
    case error(error: Error)
    
    /// The virtual machine is in the process of starting.
    case starting
    
    /// The virtual machine is in the process of pausing.
    case pausing
    
    /// The virtual machine is resuming from a paused state.
    case resuming
    
    /// The virtual machine is in the process of stopping.
    case stopping
    
    /// The virtual machine is saving its current state.
    case saving
    
    /// The virtual machine is restoring from a saved state.
    case restoring
    
    /// The virtual machine is being installed.
    ///
    /// - Parameter progress: A value between 0.0 and 1.0 indicating the installation progress.
    case installing(progress: Double)
    
    // MARK: - Properties
    
    /// Returns the color associated with the current state of the virtual machine.
    ///
    /// Use this property in SwiftUI views to visually indicate the status of
    /// the virtual machine. For example:
    /// - `.green` for `.running`
    /// - `.red` for `.stopped`
    /// - `.orange` for transition states.
    public var color: Color {
        switch self {
        case .stopped: .red
        case .running: .green
        case .error: .yellow
        case .paused, .starting, .pausing, .resuming, .stopping, .saving, .restoring: .orange
        case .installing: .mint
        }
    }
    
    /// Returns a localized string representing the current state of the virtual machine.
    ///
    /// This property retrieves a localized string for the state, using localization keys defined
    /// in the framework's bundle. This allows for seamless integration of localized text in SwiftUI views.
    public var localizedName: String {
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
    
    /// The raw integer value representing the current state.
    ///
    /// This value is used to map the state to a primitive value for serialization or interoperation with
    /// other systems. Each state corresponds to a unique integer.
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
    
    /// Initializes an `ExecutionState` from a raw integer value.
    ///
    /// - Parameter rawValue: The raw value representing the desired state.
    /// - Returns: An instance of `ExecutionState`, or `nil` if the raw value does not correspond to a valid state.
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
    
    /// Initializes an `ExecutionState` from a `VZVirtualMachine.State`.
    ///
    /// - Parameter vzState: The `VZVirtualMachine.State` to map to an `ExecutionState`.
    init?(_ vzState: VZVirtualMachine.State) {
        self.init(rawValue: vzState.rawValue)
    }
}
