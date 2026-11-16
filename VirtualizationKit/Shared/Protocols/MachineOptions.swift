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

/// The settings of a virtual machine that only one backend understands.
///
/// A template describes a machine in terms every backend shares: processors, memory, disks, network,
/// display. Whatever is meaningful to a single backend, such as the platform a guest of the Apple
/// backend runs on or the graphics device QEMU exposes, lives in the options type of that backend.
///
/// Options are as much a part of the identity of a machine as its template is: a machine restored
/// with different options is a different machine. An application persists the two together.
///
/// ## Defaults
/// Every options type has a default, which is what `VirtualMachine.init(template:)` uses. The defaults
/// of the backends shipped with the framework describe the same kind of machine, a 64-bit ARM Linux
/// guest, which is also the case where one template can be run by either backend.
///
/// - Important: An application that relies on a default persists it implicitly. Conforming types must
///   therefore never change what their default means from one release to the next.
public protocol MachineOptions: Transferable {

    /// The options a virtual machine is created with when none are given.
    static var `default`: Self { get }
}
