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

@Suite("Machine files", .serialized)
@MainActor
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

    /// A template with a managed disk, whose machine directory lives in a temporary support directory.
    private func machine(in directory: TemporaryDirectory) -> TestTemplate {
        VirtualizationKit.setSupportDirectory(directory.url)
        var template = TestTemplate()
        template.storage = [DiskImage(location: .managed(size: 1 << 20), interface: .virtio)]
        return template
    }

    private func create(_ template: TestTemplate) throws -> URL {
        let folder = VirtualizationKit.machineDirectory(for: template)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return try DiskImageStore(directory: folder).provision(template.storage[0]).url
    }

    private func size(of file: URL) throws -> UInt64? {
        (try FileManager.default.attributesOfItem(atPath: file.path)[.size] as? NSNumber)?.uint64Value
    }

    @Test("Deleting removes the machine directory, and refuses while the machine is in use")
    func delete() async throws {
        let directory = try TemporaryDirectory()
        let template = machine(in: directory)
        try await VirtualizationKit.deleteFiles(of: template)   // nothing there yet

        _ = try create(template)
        let folder = VirtualizationKit.machineDirectory(for: template)
        var inUse: MachineLock? = try MachineLock(directory: folder)
        await #expect(throws: VZKitError.machineInUse) { try await VirtualizationKit.deleteFiles(of: template) }
        #expect(FileManager.default.fileExists(atPath: folder.path))

        _ = inUse
        inUse = nil
        try await VirtualizationKit.deleteFiles(of: template)
        #expect(!FileManager.default.fileExists(atPath: folder.path))
    }

    @Test("A managed disk grows, never shrinks, and not while the machine is in use")
    func resize() async throws {
        let directory = try TemporaryDirectory()
        var template = machine(in: directory)
        let file = try create(template)

        let grown = try await template.storage[0].resized(to: 4 << 20, in: template)
        #expect(grown.location == .managed(size: 4 << 20) && grown.id == template.storage[0].id)
        #expect(try size(of: file) == 4 << 20)
        template.storage[0] = grown

        await #expect(throws: VZKitError.cannotShrinkDisk(grown.id)) {
            try await grown.resized(to: 1 << 20, in: template)
        }
        #expect(try size(of: file) == 4 << 20)

        let inUse = try MachineLock(directory: VirtualizationKit.machineDirectory(for: template))
        await #expect(throws: VZKitError.machineInUse) {
            try await grown.resized(to: 8 << 20, in: template)
        }
        _ = inUse
    }

    @Test("Only managed disks of the template can be resized; a disk not created yet is only described")
    func resizeRules() async throws {
        let directory = try TemporaryDirectory()
        var template = machine(in: directory)

        let notCreated = try await template.storage[0].resized(to: 2 << 20, in: template)
        #expect(notCreated.location == .managed(size: 2 << 20))

        let external = DiskImage(location: .external(bookmark: Data()), interface: .usb)
        template.storage.append(external)
        await #expect(throws: VZKitError.invalidDiskImage(external.id)) {
            try await external.resized(to: 1 << 30, in: template)
        }

        let stranger = DiskImage(location: .managed(size: 1 << 20), interface: .virtio)
        await #expect(throws: VZKitError.invalidDiskImage(stranger.id)) {
            try await stranger.resized(to: 1 << 30, in: template)
        }
    }

    @Test("The size of a disk: the capacity it describes, or the length of an external image")
    func size() throws {
        let directory = try TemporaryDirectory()
        #expect(try DiskImage(location: .managed(size: 3 << 20), interface: .virtio).size() == 3 << 20)

        let file = directory.file("data.img", size: 4096)
        #expect(try DiskImage(location: .external(bookmark: try bookmark(to: file)), interface: .usb).size() == 4096)

        #expect(throws: VZKitError.diskImageUnreachable(nil)) {
            try DiskImage(location: .external(bookmark: Data([0xFF])), interface: .usb).size()
        }
    }
}
