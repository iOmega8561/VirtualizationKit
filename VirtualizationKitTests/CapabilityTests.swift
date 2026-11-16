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

@Suite("Capabilities and validation")
struct CapabilityTests {

    private typealias Apple = AppleVirtualMachine<TestTemplate>
    private typealias QEMU = QEMUConfigurationBuilder<TestTemplate>

    private let linux = AppleMachineOptions.default
    private let macOS13 = AppleMachineOptions(platform: .macOS(version: .init(major: 13, minor: 0, patch: 0)))
    private let macOS12 = AppleMachineOptions(platform: .macOS(version: .init(major: 12, minor: 4, patch: 0)))

    // MARK: - Apple

    @Test("Apple: what depends on the guest platform or the backend")
    func appleTable() {
        #expect(Apple.support(for: .rosetta, options: macOS13) == .unsupported(.guestPlatform))
        #expect(Apple.support(for: .nestedVirtualization, options: macOS13) == .unsupported(.guestPlatform))
        #expect(Apple.support(for: .directoryShare, options: linux) == .supported)
        #expect(Apple.support(for: .directoryShare, options: macOS13) == .supported)
        #expect(Apple.support(for: .directoryShare, options: macOS12) == .unsupported(.guestPlatform))
        #expect(Apple.support(for: .audioOutputDevice, options: macOS12) == .supported)
        #expect(Apple.support(for: .audioCaptureDevice, options: linux) == .supported)
        for capability in [OptionalCapability.entropyDevice, .memoryBalloonDevice] {
            #expect(Apple.support(for: capability, options: linux) == .supported)
            #expect(Apple.support(for: capability, options: macOS13) == .supported)
            #expect(QEMU.support(for: capability, options: .default, helper: nil) == .supported)
        }
        for capability in [OptionalCapability.tpm, .secureBoot] {
            #expect(Apple.support(for: capability, options: linux) == .unsupported(.backend))
            #expect(Apple.support(for: capability, options: macOS13) == .unsupported(.backend))
        }
    }

    @Test("Apple: what depends on the host is never blamed on the backend or the guest")
    func appleHost() {
        for capability in [OptionalCapability.rosetta, .nestedVirtualization, .xhciUSBHotSwap] {
            let support = Apple.support(for: capability, options: linux)
            #expect(support != .unsupported(.backend) && support != .unsupported(.guestPlatform), "\(capability)")
        }
        if #available(macOS 15.0, *) {
            #expect(Apple.support(for: .xhciUSBHotSwap, options: linux) == .supported)
        } else {
            #expect(Apple.support(for: .xhciUSBHotSwap, options: linux) == .unsupported(.hostSystem))
        }
    }

    @Test("Apple: validation names the capability and the reason")
    func appleCapabilityValidation() {
        var template = TestTemplate()
        template.optionalCapabilities = [.audioOutputDevice, .tpm]
        #expect(throws: VZKitError.unsupportedFeature(.tpm, .backend)) {
            try Apple.validate(template, options: linux)
        }
        template.optionalCapabilities = [.rosetta]
        #expect(throws: VZKitError.unsupportedFeature(.rosetta, .guestPlatform)) {
            try Apple.validate(template, options: macOS13)
        }
    }

    @Test("Apple: validation of disks")
    func appleStorageValidation() throws {
        var template = TestTemplate()
        template.storage = [DiskImage(location: .managed(size: 4096), interface: .nvme)]
        try Apple.validate(template, options: linux)
        #expect(throws: VZKitError.unsupportedDiskInterface(.disk, .nvme)) {
            try Apple.validate(template, options: macOS13)
        }

        let disk = DiskImage(location: .managed(size: 4096), interface: .virtio)
        template.storage = [disk, disk]
        #expect(throws: VZKitError.invalidDiskImage(disk.id)) { try Apple.validate(template, options: linux) }
    }

    // MARK: - QEMU

    @Test("QEMU: without the helper, what needs its payload is unavailable")
    func qemuWithoutHelper() {
        let options = QEMUMachineOptions.default
        #expect(QEMU.support(for: .tpm, options: options, helper: nil) == .unavailable(.frameworkPayload))
        #expect(QEMU.support(for: .secureBoot, options: options, helper: nil) == .unavailable(.frameworkPayload))
        #expect(QEMU.support(for: .audioOutputDevice, options: options, helper: nil) == .supported)
        #expect(QEMU.support(for: .xhciUSBHotSwap, options: options, helper: nil) == .supported)
        for capability in [OptionalCapability.rosetta, .nestedVirtualization, .directoryShare, .audioCaptureDevice] {
            #expect(QEMU.support(for: capability, options: options, helper: nil) == .unsupported(.backend))
        }
    }

    @Test("QEMU: a payload without the TPM is reported, and validation names the missing file")
    func qemuPayload() throws {
        let directory = try TemporaryDirectory()
        let complete = try FakeHelperBundle(in: directory)
        #expect(QEMU.support(for: .tpm, options: .default, helper: complete.bundle) == .supported)
        #expect(QEMU.support(for: .secureBoot, options: .init(architecture: .x86_64), helper: complete.bundle) == .supported)

        try FileManager.default.removeItem(at: complete.url.appendingPathComponent("Contents/MacOS/QEMUTPM"))
        #expect(QEMU.support(for: .tpm, options: .default, helper: complete.bundle) == .unavailable(.frameworkPayload))

        var template = TestTemplate()
        template.optionalCapabilities = [.tpm]
        #expect(throws: VZKitError.qemuPayloadMissing("QEMUTPM")) {
            try QEMU.validate(template, options: .default, helper: complete.bundle)
        }
    }

    @Test("QEMU: validation of disks and network")
    func qemuValidation() throws {
        let directory = try TemporaryDirectory()
        let helper = try FakeHelperBundle(in: directory).bundle

        var template = TestTemplate()
        template.storage = [DiskImage(location: .external(bookmark: Data()), kind: .optical, interface: .virtio)]
        #expect(throws: VZKitError.unsupportedDiskInterface(.optical, .virtio)) {
            try QEMU.validate(template, options: .default, helper: helper)
        }

        template.storage = []
        template.networkTopology = .bridged()
        #expect(throws: VZKitError.self) { try QEMU.validate(template, options: .default, helper: helper) }
    }

    @Test("QEMU: removable drives need the hot-plug capability, as on the Apple backend")
    func qemuDrives() throws {
        #expect(throws: VZKitError.featureNotEnabled(.xhciUSBHotSwap)) {
            try QEMUVirtualMachine<TestTemplate>.checkRemovableDriveSupport(in: TestTemplate())
        }
        var template = TestTemplate()
        template.optionalCapabilities = [.xhciUSBHotSwap]
        try QEMUVirtualMachine<TestTemplate>.checkRemovableDriveSupport(in: template)
    }
}
