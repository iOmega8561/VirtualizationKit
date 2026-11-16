//
//  Copyright 2025 Giuseppe Rocco
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
//  -----------------------------------------------------------------------
//
//  ExecutionState.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 20/01/25.
//

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
///
/// - Note: `init?(rawValue:)` cannot produce `.error` and `.installing`, which carry a value. Encoding and
///   decoding preserve every state, value included; see `encode(to:)`.
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
    /// The mapping is spelled out case by case rather than going through raw values, which would tie
    /// this type to the numbering of Virtualization.framework.
    ///
    /// - Parameter vzState: The `VZVirtualMachine.State` to map to an `ExecutionState`.
    /// - Returns: `nil` for `.error`, which needs the error it carries (the delegate of the machine reports
    ///   it), and for states added to the framework later.
    init?(_ vzState: VZVirtualMachine.State) {
        switch vzState {
        case .stopped: self = .stopped
        case .running: self = .running
        case .paused: self = .paused
        case .error: return nil
        case .starting: self = .starting
        case .pausing: self = .pausing
        case .resuming: self = .resuming
        case .stopping: self = .stopping
        case .saving: self = .saving
        case .restoring: self = .restoring
        @unknown default: return nil
        }
    }

    // MARK: - Actions

    /// Whether a virtual machine in this state can be started: it is stopped, or it stopped because of an error.
    public var allowsStart: Bool {
        switch self {
        case .stopped, .error: true
        case .running, .paused, .starting, .pausing, .resuming, .stopping, .saving, .restoring, .installing: false
        }
    }

    /// Whether a virtual machine in this state can be stopped: it is running or paused.
    public var allowsStop: Bool {
        switch self {
        case .running, .paused: true
        case .stopped, .error, .starting, .pausing, .resuming, .stopping, .saving, .restoring, .installing: false
        }
    }

    /// Whether a virtual machine in this state can be paused: it is running.
    public var allowsPause: Bool {
        if case .running = self { true } else { false }
    }

    /// Whether a virtual machine in this state can be resumed: it is paused.
    public var allowsResume: Bool {
        if case .paused = self { true } else { false }
    }
}

// MARK: - Codable

extension ExecutionState {

    /// An error restored from an encoded execution state.
    ///
    /// Errors are not encodable in general, so an `.error` state keeps only the description of its
    /// error when it is encoded. Decoding gives it back as this type, which compares equal to the
    /// original state.
    public struct RestoredError: LocalizedError, Sendable, Hashable {

        /// The description of the original error.
        public let errorDescription: String?
    }

    /// The keys of the encoded form of the states that carry a value.
    private enum CodingKeys: String, CodingKey {
        case state, progress, error
    }

    /// Encodes the state.
    ///
    /// States without a value are encoded as their raw value, as before. `.installing` and `.error`
    /// are encoded as an object that also holds the progress, or the description of the error.
    ///
    /// - Parameter encoder: The encoder to write to.
    public func encode(to encoder: any Encoder) throws {
        switch self {
        case .installing(let progress):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(rawValue, forKey: .state)
            try container.encode(progress, forKey: .progress)

        case .error(let error):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(rawValue, forKey: .state)
            try container.encode(error.localizedDescription, forKey: .error)

        default:
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
        }
    }

    /// Decodes a state, in either of the forms `encode(to:)` writes.
    ///
    /// Before 2.0 every state was encoded as its bare raw value, including `.error` and `.installing`, which
    /// then failed to decode. They decode now, without the value they never stored: an error with no
    /// description, and no installation progress.
    ///
    /// - Parameter decoder: The decoder to read from.
    public init(from decoder: any Decoder) throws {
        if let single = try? decoder.singleValueContainer(), let rawValue = try? single.decode(RawValue.self) {
            switch rawValue {
            case ExecutionState.installing(progress: 0).rawValue:
                self = .installing(progress: 0)

            case ExecutionState.error(error: RestoredError(errorDescription: nil)).rawValue:
                self = .error(error: RestoredError(errorDescription: nil))

            default:
                guard let state = ExecutionState(rawValue: rawValue) else {
                    throw DecodingError.dataCorruptedError(
                        in: single,
                        debugDescription: "No execution state with raw value \(rawValue)"
                    )
                }
                self = state
            }
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)

        switch try container.decode(RawValue.self, forKey: .state) {
        case ExecutionState.installing(progress: 0).rawValue:
            self = .installing(progress: try container.decode(Double.self, forKey: .progress))

        case ExecutionState.error(error: RestoredError(errorDescription: nil)).rawValue:
            let description = try container.decodeIfPresent(String.self, forKey: .error)
            self = .error(error: RestoredError(errorDescription: description))

        case let rawValue:
            guard let state = ExecutionState(rawValue: rawValue) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .state,
                    in: container,
                    debugDescription: "No execution state with raw value \(rawValue)"
                )
            }
            self = state
        }
    }
}
