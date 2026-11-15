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
//  OptionalCapability.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 10/01/25.
//

import Foundation

import Virtualization

/// An enumeration of optional features available within VirtualizationKit.
///
/// `OptionalCapability` defines a set of capabilities that can be supported on either the host system
/// or the guest virtual machine. Each case is associated with metadata that includes a localization key
/// and a scope (host or guest) to facilitate consistent UI representation and internationalization.
///
/// ### Key Features
/// - **Localization**: Each capability exposes a `localizedName` property that returns its localized name
///   using VirtualizationKit's localization utilities.
/// - **Scope**: The `featureScope` property indicates whether the capability applies to the host system or the guest VM.
/// - **Extensibility**: New capabilities can be added by defining additional cases and updating the corresponding metadata.
///
/// ### Supported Capabilities
/// - **rosetta**: Represents the Rosetta translation layer available on the host system.
/// - **nestedVirtualization**: Represents support for nested virtualization on the host.
///   *Note*: Requires macOS 15 or later and appropriate hardware support (e.g., Apple M3).
/// - **xhciUSBHotSwap**: Represents support for XHCI USB hot-swapping on the host.
/// - **directoryShare**: Represents the ability to share directories with the guest virtual machine.
/// - **audioCaptureDevice**: Represents the ability to use the host's microphone for audio capture.
/// - **audioOutputDevice**: Represents the ability to use the host's speakers for audio output.
/// - **tpm**: Represents a TPM 2.0 device in the virtual machine.
/// - **secureBoot**: Represents UEFI firmware that supports Secure Boot.
///
/// ### Backends
/// No backend provides every capability. Ask the backend at hand with `VirtualMachine.support(for:options:)`;
/// a template asking for a capability its backend does not provide is rejected when it is validated.
///
/// ### Example Usage
/// ```swift
/// let capability: OptionalCapability = .rosetta
/// print("Capability: \(capability.localizedName)") // Prints the localized name
/// print("Scope: \(capability.featureScope.rawValue)")   // Prints "Host" or "Guest"
/// ```
///
/// `OptionalCapability` conforms to `Transferable` for seamless integration within VirtualizationKit.
public enum OptionalCapability: Transferable, CaseIterable {
    
    // MARK: - Supporting Types
    
    /// Represents the scope of a capability: whether it applies to the host or the guest virtual machine.
    private enum Scope: String {
        case host = "Host"
        case guest = "Guest"
    }
    
    /// Encapsulates metadata associated with a capability, including its localization key and scope.
    private struct MetaData {
        /// The localization key for the capability's name.
        let localizationKey: String.LocalizationValue
        /// The scope indicating whether the capability is a host or guest feature.
        let featureScope: Scope
        /// Returns the localized name of the capability.
        var localizedName: String { VZKitLocale(localizationKey).value }
    }
    
    // MARK: - Static properties
    
    /// Indicates if nested virtualization is supported on the current host.
    @available(macOS 15.0, *)
    public static var isNestedVirtualizationSupported: Bool {
        VZGenericPlatformConfiguration.isNestedVirtualizationSupported
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
    
    /// Represents the ability to use the host's microphone for audio capture.
    case audioCaptureDevice
    
    /// Represents the ability to use the host's speakers for audio output.
    case audioOutputDevice
    
    /// Represents a TPM 2.0 device in the virtual machine.
    ///
    /// The state of the TPM (keys, counters) is kept in a file of the machine that survives power cycles.
    /// Windows 11 requires one, and any guest can use it for measured boot or disk encryption.
    case tpm

    /// Represents UEFI firmware that supports Secure Boot.
    ///
    /// The firmware starts without enrolled keys: Secure Boot is available, and can be enabled
    /// from the firmware setup or by the guest, but signatures are not checked until keys are
    /// enrolled. The firmware keeps its settings in a variable store of its own, so adding or removing
    /// this capability makes the machine start with fresh firmware settings (boot entries included).
    case secureBoot

    // MARK: - Private Metadata Access
    
    /// Retrieves the metadata for each capability, including its localization key and scope.
    private var metaData: MetaData {
        switch self {
        case .rosetta: .init(localizationKey: "capability-rosetta", featureScope: .host)
        case .nestedVirtualization: .init(localizationKey: "capability-nestedVirtualization", featureScope: .host)
        case .xhciUSBHotSwap: .init(localizationKey: "capability-xhciUSBHotSwap", featureScope: .host)
        case .directoryShare: .init(localizationKey: "capability-directoryShare", featureScope: .guest)
        case .audioCaptureDevice: .init(localizationKey: "capability-audioCaptureDevice", featureScope: .host)
        case .audioOutputDevice: .init(localizationKey: "capability-audioOutputDevice", featureScope: .host)
        case .tpm: .init(localizationKey: "capability-tpm", featureScope: .host)
        case .secureBoot: .init(localizationKey: "capability-secureBoot", featureScope: .host)
        }
    }
    
    // MARK: - Instance Properties
    
    /// The localized name of the capability.
    public var localizedName: String { metaData.localizedName }
    
    /// The scope of the capability, indicating whether it applies to the host or guest.
    public var featureScope: String { metaData.featureScope.rawValue }
}
