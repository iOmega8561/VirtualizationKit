//
//  VZKitFeature.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 10/01/25.
//

import Foundation

/// Represents a set of features available within the `VZKit` framework.
///
/// The `VZKitFeature` enum encapsulates a predefined set of features that can be supported by
/// either the host system or the guest virtual machine. Each feature includes metadata that
/// describes its localization key and scope (e.g., host or guest), allowing for consistent
/// representation and translation.
///
/// ## Features
/// - Provides localized names for features using the `VZKitLocale` utility.
/// - Defines whether a feature applies to the host system or the guest virtual machine.
/// - Easily extendable to accommodate additional features.
///
/// ## Enum Cases
/// - `.rosetta`: Represents the Rosetta translation layer for the host system.
/// - `.nestedVirtualization`: Represents nested virtualization support on the host.
/// - `.xhciUSBHotSwap`: Represents support for XHCI USB hot-swapping on the host.
/// - `.directoryShare`: Represents the ability to share directories with the guest virtual machine.
///
/// ## Usage
/// ```swift
/// let feature = VZKitFeature.rosetta
/// print("Feature: \(feature.localized)") // Localized name
/// print("Scope: \(feature.scope)")       // "Host" or "Guest"
/// ```
///
/// ## Localization
/// - Each feature includes a `localized` property that retrieves its localized name
///   using the framework's localization resources.
/// - The `scope` property provides a localized string indicating whether the feature
///   applies to the host or guest.
///
/// ## Extensibility
/// New features can be added by defining additional cases and updating the `metaData`
/// property to include the appropriate localization key and scope.
///
/// ## Implementation Details
/// - **Scope**: A private enum defining whether a feature applies to the host or guest.
/// - **MetaData**: A private structure encapsulating the localization key and scope of a feature.
public enum VZKitFeature: VZKitTransferable {
    
    // MARK: - Private Types
    
    /// Defines the scope of a feature (host or guest).
    private enum Scope {
        case host
        case guest
    }
    
    /// Encapsulates metadata for a feature, including its localization key and scope.
    private struct MetaData {
        let key: String.LocalizationValue
        let scope: Scope
    }
    
    // MARK: - Enum Cases
    
    /// Represents the Rosetta translation layer for the host system.
    case rosetta
    
    /// Represents nested virtualization support on the host.
    case nestedVirtualization
    
    /// Represents support for XHCI USB hot-swapping on the host.
    case xhciUSBHotSwap
    
    /// Represents the ability to share directories with the guest virtual machine.
    case directoryShare
    
    /// Represents the ability to use the microphone of the host macintosh
    case audioCaptureDevice
    
    /// Represents the ability to use the speakers of the host macintosh
    case audioOutputDevice
    
    // MARK: - Private Metadata
    
    /// Provides metadata for each feature, including its localization key and scope.
    private var metaData: MetaData {
        switch self {
        case .rosetta: .init(key: "feature-rosetta", scope: .host)
        case .nestedVirtualization: .init(key: "feature-nestedVirtualization", scope: .host)
        case .xhciUSBHotSwap: .init(key: "feature-xhciUSBHotSwap", scope: .host)
        case .directoryShare: .init(key: "feature-directoryShare", scope: .guest)
        case .audioCaptureDevice: .init(key: "feature-audioCaptureDevice", scope: .host)
        case .audioOutputDevice: .init(key: "feature-audioOutputDevice", scope: .host)
        }
    }
    
    // MARK: - Public Properties
    
    /// The localized name of the feature.
    ///
    /// This property retrieves the feature's name from the framework's localization resources
    /// using the `VZKitLocale` utility and the associated localization key.
    public var localized: String {
        VZKitLocale(self.metaData.key).value
    }
    
    // MARK: - Internal Properties
    
    /// The localized scope of the feature (host or guest).
    ///
    /// This property retrieves a localized string indicating whether the feature applies to
    /// the host system or the guest virtual machine. It uses the `VZKitLocale` utility for
    /// consistent translation.
    var scope: String {
        switch self.metaData.scope {
        case .host: "Host"
        case .guest: "Guest"
        }
    }
}
