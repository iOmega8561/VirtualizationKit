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
import Testing
@testable import VirtualizationKit

@Suite("Machine files")
struct MachineFilesTests {

    @Test("A machine directory can be locked once at a time, and is free again when released")
    func lock() throws {
        let directory = try TemporaryDirectory()
        var first: MachineLock? = try MachineLock(directory: directory.url)
        #expect(throws: VZKitError.machineInUse) { try MachineLock(directory: directory.url) }
        _ = first
        first = nil
        _ = try MachineLock(directory: directory.url)
    }

    @Test("A second QEMU machine for the same template is refused while the first exists")
    func secondQEMUMachine() throws {
        let directory = try TemporaryDirectory()
        let helper = try FakeHelperBundle(in: directory)
        let storage = QEMUMachineStorage(directory: directory.url.appendingPathComponent("machine"))
        var template = TestTemplate()
        template.storage = [DiskImage(location: .managed(size: 4096), interface: .virtio, bootOrder: 0)]
        let builder = QEMUConfigurationBuilder(template: template, options: .default, helper: helper.bundle, storage: storage)

        let first = try builder.createLaunchPlan()
        #expect(throws: VZKitError.machineInUse) { try builder.createLaunchPlan() }
        _ = first
    }

    @Test("The shared folder is one safe path component named after the template")
    func sharedFolderName() {
        typealias Builder = AppleConfigurationBuilder<TestTemplate>
        #expect(Builder.sharedFolderName(for: "Ubuntu 24.04") == "Ubuntu 24.04")
        #expect(Builder.sharedFolderName(for: "../../Documents") == "-..-Documents")
        #expect(Builder.sharedFolderName(for: "a/b:c") == "a-b-c")
        #expect(Builder.sharedFolderName(for: ".hidden") == "hidden")
        #expect(Builder.sharedFolderName(for: "  ") == "Shared")
        #expect(Builder.sharedFolderName(for: "..") == "Shared")
    }
}
