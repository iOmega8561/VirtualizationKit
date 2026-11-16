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

/// An enumeration of optional features available within VirtualizationKit.
///
/// `OptionalCapability` defines a set of features a template can ask for on top of the machine every
/// backend builds. A capability names the feature only; whether it can be provided depends on the
/// backend, its options and the host, and is answered by `VirtualMachine.support(for:options:)`
/// together with the reason when it cannot.
///
/// ### Key Features
/// - **Localization**: Each capability exposes a `localizedName` property that returns its localized name
///   using VirtualizationKit's localization utilities.
/// - **Extensibility**: New capabilities can be added by defining additional cases. Every backend then has
///   to say whether it provides them before the framework compiles again.
///
/// ### Supported Capabilities
/// - **rosetta**: Represents the Rosetta translation layer available on the host system.
/// - **nestedVirtualization**: Represents the ability to run a hypervisor inside the guest.
/// - **xhciUSBHotSwap**: Represents support for XHCI USB hot-swapping on the host.
/// - **directoryShare**: Represents the ability to share directories with the guest virtual machine.
/// - **audioCaptureDevice**: Represents the ability to use the host's microphone for audio capture.
/// - **audioOutputDevice**: Represents the ability to use the host's speakers for audio output.
/// - **tpm**: Represents a TPM 2.0 device in the virtual machine.
/// - **secureBoot**: Represents UEFI firmware that supports Secure Boot.
/// - **entropyDevice**: Represents a paravirtualized random number generator for the guest.
/// - **memoryBalloonDevice**: Represents a paravirtualized memory balloon for the guest.
///
/// ### Backends
/// No backend provides every capability. Ask the backend at hand with `VirtualMachine.support(for:options:)`;
/// a template asking for a capability its backend does not provide is rejected when it is validated.
///
/// ### Example Usage
/// ```swift
/// let capability: OptionalCapability = .rosetta
/// print("Capability: \(capability.localizedName)") // Prints the localized name
/// ```
///
/// `OptionalCapability` conforms to `Transferable` for seamless integration within VirtualizationKit.
public enum OptionalCapability: Transferable, CaseIterable {
    
    // MARK: - Enum Cases
    
    /// Represents the Rosetta translation layer for the host system.
    case rosetta
    
    /// Represents the ability to run a hypervisor inside the guest.
    case nestedVirtualization
    
    /// Represents a USB controller that removable drives can be attached to and detached from while
    /// the virtual machine runs.
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

    /// Represents a paravirtualized random number generator, which feeds the guest's entropy pool from the host.
    ///
    /// Guests with a virtio driver (Linux, macOS) use it to have enough randomness early, during boot.
    case entropyDevice

    /// Represents a paravirtualized memory balloon, through which the host can ask the guest to give memory back.
    ///
    /// Guests with a virtio driver report how much memory they really use through it.
    case memoryBalloonDevice

    // MARK: - Instance Properties
    
    /// The localized name of the capability.
    public var localizedName: String {
        switch self {
        case .rosetta: VZKitLocale("capability-rosetta").value
        case .nestedVirtualization: VZKitLocale("capability-nestedVirtualization").value
        case .xhciUSBHotSwap: VZKitLocale("capability-xhciUSBHotSwap").value
        case .directoryShare: VZKitLocale("capability-directoryShare").value
        case .audioCaptureDevice: VZKitLocale("capability-audioCaptureDevice").value
        case .audioOutputDevice: VZKitLocale("capability-audioOutputDevice").value
        case .tpm: VZKitLocale("capability-tpm").value
        case .secureBoot: VZKitLocale("capability-secureBoot").value
        case .entropyDevice: VZKitLocale("capability-entropyDevice").value
        case .memoryBalloonDevice: VZKitLocale("capability-memoryBalloonDevice").value
        }
    }
}
