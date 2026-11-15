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

/// Whether a backend can provide an optional capability.
///
/// A template is written in backend-neutral terms, so it can ask for more than the backend it is
/// handed to offers. This is the answer a backend gives for one capability, given its options and the
/// host it runs on. User interfaces use it to decide what to offer; the backends use the very same
/// answer when they validate a template, so the two never disagree.
///
/// ```swift
/// let support = AppleVirtualMachine<MyTemplate>.support(for: .rosetta, options: options)
/// toggle.isEnabled = support == .supported
/// ```
public enum CapabilitySupport: Sendable, Hashable {

    /// The capability can be provided.
    case supported

    /// The backend, or the platform its options select, never provides the capability.
    case unsupported

    /// The backend provides the capability in principle, but something it depends on is missing
    /// right now, such as a component that has yet to be installed on the host.
    case unavailable
}
