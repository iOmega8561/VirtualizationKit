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

/// Options that customize how an Apple virtual machine is powered on.
///
/// A value type, unlike the `VZVirtualMachineStartOptions` classes of Virtualization.framework it
/// replaces in the actions: an action can be created anywhere and executed on the queue of the
/// machine, so what it carries has to be safe to send there. The options of Virtualization.framework
/// are created on that queue, when the action is executed.
public struct AppleStartOptions: Sendable, Hashable {

    /// Whether a macOS guest starts up from macOS Recovery instead of its startup disk.
    ///
    /// Only macOS guests have a recovery system. Defaults to `false`.
    public var startsFromRecovery: Bool

    /// Creates a set of start options.
    ///
    /// - Parameter startsFromRecovery: Whether a macOS guest starts up from macOS Recovery.
    public init(startsFromRecovery: Bool = false) {
        self.startsFromRecovery = startsFromRecovery
    }
}
