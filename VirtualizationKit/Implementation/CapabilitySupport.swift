//
//  Copyright 2026 Giuseppe Rocco
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

import Foundation

/// Whether a backend can provide an optional capability, and if not, why.
///
/// A template is written in backend-neutral terms, so it can ask for more than the backend it is
/// handed to offers. This is the answer a backend gives for one capability, given its options and the
/// host it runs on. User interfaces use it to decide what to offer and to explain what they do not;
/// the backends use the very same answer when they validate a template, so the two never disagree.
///
/// Whether a capability can be provided depends on three things at once: the backend, the options
/// it is given (the platform of the guest, for instance) and the host. The reason says which of them
/// stands in the way.
///
/// ```swift
/// switch AppleVirtualMachine<MyTemplate>.support(for: .nestedVirtualization, options: options) {
/// case .supported:                     toggle.isEnabled = true
/// case .unsupported(.hostHardware):    footnote = "This Mac cannot run hypervisors inside a guest."
/// case .unsupported, .unavailable:     toggle.isEnabled = false
/// }
/// ```
public enum CapabilitySupport: Sendable, Hashable {

    /// Why a capability is never provided in a given setting.
    public enum Limitation: String, Sendable, Hashable, CaseIterable {

        /// The backend does not provide the capability at all.
        case backend

        /// The backend provides the capability, but not to guests of the platform the options select.
        case guestPlatform

        /// The version of macOS running on the host is too old.
        case hostSystem

        /// The host hardware cannot provide the capability.
        case hostHardware
    }

    /// What is missing for a capability the backend would otherwise provide.
    public enum MissingComponent: String, Sendable, Hashable, CaseIterable {

        /// Software that has to be installed on the host, such as Rosetta.
        case hostSoftware

        /// A component the framework embeds in the application, such as a file of the QEMU payload.
        case frameworkPayload
    }

    /// The capability can be provided.
    case supported

    /// The capability is never provided in this setting. The limitation says why.
    case unsupported(Limitation)

    /// The capability would be provided, but something it depends on is missing right now.
    case unavailable(MissingComponent)

    /// Whether the capability can be provided.
    public var isSupported: Bool {
        if case .supported = self { true } else { false }
    }
}

extension CapabilitySupport {

    /// Throws the error that explains why a capability cannot be provided, if it cannot.
    ///
    /// - Parameter capability: The capability this answer is about.
    /// - Throws: `VZKitError.unsupportedFeature` or `VZKitError.unavailableFeature`, carrying the reason.
    func check(_ capability: OptionalCapability) throws {
        switch self {
        case .supported: return
        case .unsupported(let limitation): throw VZKitError.unsupportedFeature(capability, limitation)
        case .unavailable(let missing): throw VZKitError.unavailableFeature(capability, missing)
        }
    }
}
