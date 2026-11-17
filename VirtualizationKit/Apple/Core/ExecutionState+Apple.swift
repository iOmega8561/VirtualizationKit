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

import Virtualization

extension ExecutionState {

    /// Initializes an `ExecutionState` from a `VZVirtualMachine.State`.
    ///
    /// The mapping is spelled out case by case rather than going through raw values, which would tie
    /// this type to the numbering of Virtualization.framework.
    ///
    /// Virtualization.framework reports an `.error` state without the error behind it; the delegate of the
    /// machine reports that separately. This state is therefore given a generic error,
    /// `VZKitError.internalVirtualizationError`, which the coordinator replaces with the specific one
    /// whenever the delegate provides it, in whichever order the two arrive.
    ///
    /// - Parameter vzState: The `VZVirtualMachine.State` to map to an `ExecutionState`.
    /// - Returns: `nil` for states added to Virtualization.framework after this was written.
    init?(_ vzState: VZVirtualMachine.State) {
        switch vzState {
        case .stopped: self = .stopped
        case .running: self = .running
        case .paused: self = .paused
        case .error: self = .error(error: VZKitError.internalVirtualizationError)
        case .starting: self = .starting
        case .pausing: self = .pausing
        case .resuming: self = .resuming
        case .stopping: self = .stopping
        case .saving: self = .saving
        case .restoring: self = .restoring
        @unknown default: return nil
        }
    }
}
