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

/// Pins the emulator command lines. A change here changes the hardware an existing machine boots with,
/// so it has to be deliberate: update the expectations together with the change, and say why.
@Suite("QEMU launch plans")
struct QEMULaunchPlanTests {

    private static let machineID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!

    private func template(_ systemInterface: DiskImage.Interface) -> TestTemplate {
        var template = TestTemplate()
        template.id = Self.machineID
        template.name = "Golden, VM"
        template.networkTopology = .nat(macAddress: "02:11:22:33:44:55")
        template.performancePreset = .custom(desiredCoreCount: 2, desiredMemorySize: 4 << 30)
        template.storage = [DiskImage(id: Self.machineID, location: .managed(size: 1 << 20), interface: systemInterface, bootOrder: 1)]
        template.optionalCapabilities = [.entropyDevice, .memoryBalloonDevice]
        return template
    }

    private func windows(installer: URL) throws -> TestTemplate {
        var template = template(.nvme)
        template.storage.append(DiskImage(
            location: .external(bookmark: try bookmark(to: installer)),
            kind: .optical, interface: .usb, bootOrder: 0
        ))
        template.optionalCapabilities += [.audioOutputDevice, .xhciUSBHotSwap, .tpm, .secureBoot]
        return template
    }

    private func plan(_ template: TestTemplate, _ options: QEMUMachineOptions, in directory: TemporaryDirectory) throws -> QEMULaunchPlan {
        let helper = try FakeHelperBundle(in: directory)
        return try QEMUConfigurationBuilder(
            template: template,
            options: options,
            helper: helper.bundle,
            storage: QEMUMachineStorage(directory: directory.url.appendingPathComponent("machine"))
        ).createLaunchPlan().plan
    }

    /// The processor and memory arguments depend on the host the test runs on.
    private func resources(of template: TestTemplate) -> (smp: String, memory: String) {
        ("\(template.performancePreset.cpuCoreCount)", "\(template.performancePreset.memorySize / (1024 * 1024))M")
    }

    private func descriptors(_ plan: QEMULaunchPlan) -> [String] {
        plan.descriptors.map { "\($0.url.lastPathComponent) \($0.access)" }
    }

    @Test("Linux on arm64")
    func linux() throws {
        let directory = try TemporaryDirectory()
        let template = template(.virtio)
        let (smp, memory) = resources(of: template)
        let plan = try plan(template, .default, in: directory)

        #expect(plan.libraryName == "qemu-aarch64-softmmu")
        #expect(plan.arguments == [
            "-nodefaults",
            "-no-user-config",
            "-display", "none",
            "-vnc", "none",
            "-S",
            "-chardev", "socket,id=qmp0,fd=3",
            "-mon", "chardev=qmp0,mode=control",
            "-name", "guest=Golden,, VM",
            "-uuid", "11111111-2222-3333-4444-555555555555",
            "-rtc", "base=utc",
            "-machine", "virt",
            "-accel", "hvf",
            "-cpu", "host",
            "-smp", smp,
            "-m", memory,
            "-add-fd", "fd=4,set=1",
            "-drive", "if=pflash,unit=0,format=raw,readonly=on,file=/dev/fdset/1",
            "-add-fd", "fd=5,set=2",
            "-add-fd", "fd=6,set=2",
            "-drive", "if=pflash,unit=1,format=raw,file=/dev/fdset/2",
            "-device", "virtio-gpu-pci,xres=1280,yres=720",
            "-device", "qemu-xhci,id=xhci",
            "-device", "usb-kbd,bus=xhci.0",
            "-device", "usb-tablet,bus=xhci.0",
            "-device", "virtio-rng-pci",
            "-device", "virtio-balloon-pci",
            "-add-fd", "fd=7,set=3",
            "-add-fd", "fd=8,set=3",
            "-drive", "if=none,id=disk0,format=raw,discard=unmap,file=/dev/fdset/3",
            "-device", "virtio-blk-pci,drive=disk0,bootindex=1",
            "-netdev", "user,id=net0",
            "-device", "virtio-net-pci,netdev=net0,mac=02:11:22:33:44:55"
        ])
        #expect(descriptors(plan) == [
            "edk2-aarch64-code.fd readOnly",
            "QEMU-aarch64-NVRAM readWrite",
            "QEMU-aarch64-NVRAM readOnly",
            "Disk-11111111-2222-3333-4444-555555555555.img readWrite",
            "Disk-11111111-2222-3333-4444-555555555555.img readOnly"
        ])
    }

    @Test("Windows on arm64, with TPM, Secure Boot and an installer")
    func windowsARM() throws {
        let directory = try TemporaryDirectory()
        let template = try windows(installer: directory.file("install.iso"))
        let (smp, memory) = resources(of: template)
        let plan = try plan(template, .init(displayDevice: .virtioGPUWithFramebuffer, clock: .localTime, guestDrawsPointer: true), in: directory)

        #expect(plan.libraryName == "qemu-aarch64-softmmu")
        #expect(plan.arguments == [
            "-nodefaults",
            "-no-user-config",
            "-display", "none",
            "-vnc", "none",
            "-S",
            "-chardev", "socket,id=qmp0,fd=3",
            "-mon", "chardev=qmp0,mode=control",
            "-name", "guest=Golden,, VM",
            "-uuid", "11111111-2222-3333-4444-555555555555",
            "-rtc", "base=localtime",
            "-machine", "virt",
            "-accel", "hvf",
            "-cpu", "host",
            "-smp", smp,
            "-m", memory,
            "-add-fd", "fd=4,set=1",
            "-drive", "if=pflash,unit=0,format=raw,readonly=on,file=/dev/fdset/1",
            "-add-fd", "fd=5,set=2",
            "-add-fd", "fd=6,set=2",
            "-drive", "if=pflash,unit=1,format=raw,file=/dev/fdset/2",
            "-device", "virtio-ramfb,xres=1280,yres=720",
            "-device", "qemu-xhci,id=xhci",
            "-device", "usb-kbd,bus=xhci.0",
            "-device", "usb-tablet,bus=xhci.0",
            "-device", "virtio-rng-pci",
            "-device", "virtio-balloon-pci",
            "-launcher-tpm", "7",
            "-chardev", "socket,id=tpm0chr,fd=100",
            "-tpmdev", "emulator,id=tpm0,chardev=tpm0chr",
            "-device", "tpm-tis-device,tpmdev=tpm0",
            "-add-fd", "fd=8,set=3",
            "-add-fd", "fd=9,set=3",
            "-drive", "if=none,id=disk0,format=raw,discard=unmap,file=/dev/fdset/3",
            "-device", "nvme,drive=disk0,serial=11111111222233334444,bootindex=1",
            "-add-fd", "fd=10,set=4",
            "-drive", "if=none,id=disk1,media=cdrom,format=raw,readonly=on,file.locking=off,file=/dev/fdset/4",
            "-device", "usb-storage,drive=disk1,removable=on,bus=xhci.0,bootindex=0",
            "-netdev", "user,id=net0",
            "-device", "virtio-net-pci,netdev=net0,mac=02:11:22:33:44:55",
            "-audiodev", "coreaudio,id=audio0",
            "-device", "intel-hda",
            "-device", "hda-output,audiodev=audio0"
        ])
        #expect(descriptors(plan) == [
            "edk2-aarch64-secure-code.fd readOnly",
            "QEMU-aarch64-secure-NVRAM readWrite",
            "QEMU-aarch64-secure-NVRAM readOnly",
            "QEMU-TPM readWrite",
            "Disk-11111111-2222-3333-4444-555555555555.img readWrite",
            "Disk-11111111-2222-3333-4444-555555555555.img readOnly",
            "install.iso readOnly"
        ])
    }

    @Test("Windows on x86_64: emulated, with its own machine, firmware and TPM device")
    func windowsX86() throws {
        let directory = try TemporaryDirectory()
        let template = try windows(installer: directory.file("install.iso"))
        let plan = try plan(template, .init(architecture: .x86_64, displayDevice: .virtioGPUWithFramebuffer, clock: .localTime, guestDrawsPointer: true), in: directory)

        #expect(plan.libraryName == "qemu-x86_64-softmmu")
        func value(after flag: String, matching prefix: String = "") -> [String] {
            plan.arguments.indices.filter { plan.arguments[$0] == flag && $0 + 1 < plan.arguments.count }
                .map { plan.arguments[$0 + 1] }.filter { $0.hasPrefix(prefix) }
        }
        #expect(value(after: "-machine") == ["q35,smm=on"])
        #expect(value(after: "-accel") == ["tcg"])
        #expect(value(after: "-cpu") == ["max"])
        #expect(value(after: "-global") == ["driver=cfi.pflash01,property=secure,value=on"])
        #expect(value(after: "-device", matching: "virtio-vga") == ["virtio-vga,xres=1280,yres=720"])
        #expect(value(after: "-device", matching: "tpm") == ["tpm-crb,tpmdev=tpm0"])
        #expect(descriptors(plan).first == "edk2-x86_64-secure-code.fd readOnly")
    }

    @Test("The random number generator and the memory balloon are there only when asked for")
    func optionalDevices() throws {
        let directory = try TemporaryDirectory()
        var template = template(.virtio)
        template.optionalCapabilities = []
        let plan = try plan(template, .default, in: directory)
        #expect(!plan.arguments.contains("virtio-rng-pci"))
        #expect(!plan.arguments.contains("virtio-balloon-pci"))
    }

    @Test("A rejected template leaves nothing behind")
    func rejectedTemplate() throws {
        let directory = try TemporaryDirectory()
        var template = template(.virtio)
        template.storage.append(DiskImage(location: .external(bookmark: Data()), kind: .optical, interface: .virtio))

        #expect(throws: VZKitError.unsupportedDiskInterface(.optical, .virtio)) {
            try plan(template, .default, in: directory)
        }
        #expect(!directory.exists("machine"))
    }
}
