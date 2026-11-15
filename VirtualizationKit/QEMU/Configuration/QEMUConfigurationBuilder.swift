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

/// Turns a backend-neutral template into the launch plan of an emulator process.
///
/// This is the QEMU counterpart of the configuration builder of the Apple backend. It validates what
/// the template asks for against what this backend can deliver, then provisions the files of the
/// machine, and finally emits a command line that references those files through brokered descriptors
/// only. A template that is rejected leaves nothing behind on disk.
///
/// The builder is split by concern. This file holds validation and the machine itself (processor,
/// memory, firmware, display and input devices); storage, networking and audio live in extensions.
struct QEMUConfigurationBuilder<Template: TransferableTemplate>: Sendable {

    /// A copy of the template describing the machine.
    let template: Template

    /// The backend-specific settings of the machine.
    let options: QEMUMachineOptions

    /// The helper service bundle, which carries the emulator libraries and data files.
    let helper: QEMUHelperBundle

    /// The on-disk layout of the machine.
    let storage: QEMUMachineStorage

    // MARK: - Validation

    /// The file of the helper payload a capability cannot do without, if there is one.
    ///
    /// - Parameters:
    ///   - capability: A capability this backend provides.
    ///   - options: The backend-specific settings of the machine.
    ///   - helper: The helper service bundle.
    /// - Returns: The location the file is expected at, or `nil` if the capability needs no file.
    private static func payload(
        for capability: OptionalCapability,
        options: QEMUMachineOptions,
        in helper: QEMUHelperBundle
    ) -> URL? {
        switch capability {
        case .tpm:
            helper.tpmExecutableURL

        case .secureBoot:
            helper.dataDirectory.appendingPathComponent(
                QEMUMachineStorage.firmwareCodeName(for: options.architecture, secureBoot: true),
                isDirectory: false
            )

        case .rosetta, .nestedVirtualization, .xhciUSBHotSwap, .directoryShare,
             .audioCaptureDevice, .audioOutputDevice:
            nil
        }
    }

    /// Tells whether this backend can provide an optional capability.
    ///
    /// The single source of truth for capabilities: `validate` acts on the same answer. There is
    /// deliberately no `default`, so a capability added to the framework does not compile until this
    /// backend has an answer for it.
    ///
    /// - Parameters:
    ///   - capability: The capability in question.
    ///   - options: The backend-specific settings of the machine.
    ///   - helper: The helper service bundle, or `nil` if it is not embedded. Without it, everything
    ///     that needs a file of its payload is unavailable.
    /// - Returns: Whether the capability is supported, never provided, or unavailable for the time being.
    static func support(
        for capability: OptionalCapability,
        options: QEMUMachineOptions,
        helper: QEMUHelperBundle?
    ) -> CapabilitySupport {

        switch capability {
        case .audioOutputDevice, .xhciUSBHotSwap:
            return .supported

        case .tpm, .secureBoot:
            guard let helper,
                  let file = payload(for: capability, options: options, in: helper),
                  FileManager.default.fileExists(atPath: file.path(percentEncoded: false)) else {
                return .unavailable
            }
            return .supported

        case .rosetta, .nestedVirtualization, .directoryShare, .audioCaptureDevice:
            return .unsupported
        }
    }

    /// Rejects templates that ask for something this backend cannot provide.
    ///
    /// Failing here, before anything is provisioned or launched, yields the same localized errors the
    /// Apple backend reports for unsupported features. Nothing is created or modified on disk.
    ///
    /// - Parameters:
    ///   - template: The template describing the machine.
    ///   - options: The backend-specific settings of the machine.
    ///   - helper: The helper service bundle, which carries the emulator libraries and data files.
    static func validate(
        _ template: Template,
        options: QEMUMachineOptions,
        helper: QEMUHelperBundle
    ) throws {

        for capability in template.optionalCapabilities {
            switch support(for: capability, options: options, helper: helper) {
            case .supported:
                continue

            case .unsupported:
                throw VZKitError.unsupportedFeature(capability)

            case .unavailable:
                // On this backend a capability is only ever unavailable for want of a file of the
                // payload. Naming the file is more useful than naming the capability.
                guard let file = payload(for: capability, options: options, in: helper) else {
                    throw VZKitError.unavailableFeature(capability)
                }
                throw VZKitError.qemuFirmwareMissing(file.lastPathComponent)
            }
        }

        try validateStorage(template.storage)

        if case .bridged = template.networkTopology {
            throw VZKitError.qemuUnsupportedNetwork(template.networkTopology.localizedName)
        }

        let library = helper.libraryURL(named: options.architecture.libraryName)

        guard FileManager.default.fileExists(atPath: library.path(percentEncoded: false)) else {
            throw VZKitError.qemuFirmwareMissing(library.lastPathComponent)
        }
    }

    /// Checks the disks of the template against what this backend can attach.
    ///
    /// On top of the rules every backend shares, an optical disc needs a bus that has optical drives.
    /// Of the interfaces a disk can ask for, that is USB only.
    private static func validateStorage(_ storage: [DiskImage]) throws {

        try DiskImage.validate(storage)

        for disk in storage {

            switch disk.format {
            case .raw: break
            }

            switch (disk.kind, disk.interface) {
            case (.disk, _), (.optical, .usb): break
            case (.optical, .virtio), (.optical, .nvme):
                throw VZKitError.unsupportedDiskInterface(disk.kind, disk.interface)
            }
        }
    }

    // MARK: - Machine

    /// Emits the options that are independent of the template: no implicit devices, no local display,
    /// and a control channel on the descriptor the helper service provides.
    private func appendBaseline(to plan: inout QEMULaunchPlan) {

        plan.append("-nodefaults", "-no-user-config")
        plan.append("-display", "none")

        // The display server is initialised but does not listen anywhere. Clients are handed in
        // over the control channel, one connected socket at a time.
        plan.append("-vnc", "none")

        // The guest is created halted, so the control channel and the display are in place
        // before the first instruction runs.
        plan.append("-S")

        plan.append("-chardev", "socket,id=qmp0,fd=\(QEMULaunchPlan.controlDescriptor)")
        plan.append("-mon", "chardev=qmp0,mode=control")

        if !template.name.isEmpty {
            plan.append("-name", "guest=\(QEMULaunchPlan.escape(template.name))")
        }

        plan.append("-uuid", template.id.uuidString.lowercased())
        switch options.clock {
        case .utc: plan.append("-rtc", "base=utc")
        case .localTime: plan.append("-rtc", "base=localtime")
        }
    }

    /// Emits the machine type, the accelerator and the processor and memory resources.
    private func appendPlatform(to plan: inout QEMULaunchPlan) {

        switch options.architecture {
        case .aarch64:
            plan.append("-machine", "virt")
            plan.append("-accel", "hvf")
            plan.append("-cpu", "host")

        case .x86_64 where usesSecureBoot:
            // The Secure Boot firmware for x86 protects its variables with System Management Mode.
            plan.append("-machine", "q35,smm=on")
            plan.append("-accel", "tcg")
            plan.append("-cpu", "max")

        case .x86_64:
            plan.append("-machine", "q35")
            plan.append("-accel", "tcg")
            plan.append("-cpu", "max")
        }

        plan.append("-smp", "\(template.performancePreset.cpuCoreCount)")
        plan.append("-m", "\(template.performancePreset.memorySize / (1024 * 1024))M")
    }

    /// Emits the UEFI firmware: read-only code out of the helper bundle, plus the per-machine variable store.
    private func appendFirmware(to plan: inout QEMULaunchPlan) throws {

        let secureBoot = usesSecureBoot

        let code = plan.broker(.init(
            url: try storage.firmwareCode(for: options.architecture, secureBoot: secureBoot, in: helper),
            access: .readOnly
        ))

        plan.append("-drive", "if=pflash,unit=0,format=raw,readonly=on,file=\(code)")

        // Only code running in System Management Mode may write the variables of the x86 Secure Boot
        // firmware; that is what keeps the guest from changing its keys behind the firmware's back.
        if secureBoot, case .x86_64 = options.architecture {
            plan.append("-global", "driver=cfi.pflash01,property=secure,value=on")
        }

        let variables = plan.broker(.init(
            url: try storage.prepareVariableStore(for: options.architecture, secureBoot: secureBoot, in: helper),
            access: .readWrite
        ))

        plan.append("-drive", "if=pflash,unit=1,format=raw,file=\(variables)")
    }

    /// Emits the devices every machine has: a paravirtualised display, a USB controller with a keyboard
    /// and an absolute pointing device, an entropy source and a memory balloon.
    private func appendCoreDevices(to plan: inout QEMULaunchPlan) {

        let resolution = "xres=\(template.display.width),yres=\(template.display.height)"

        switch options.architecture {
        case .aarch64 where usesFramebufferDisplay:
            // A virtio GPU that also exposes a RAM framebuffer, which the firmware and guests without
            // a virtio GPU driver (Windows' basic display driver, for one) draw to.
            plan.append("-device", "virtio-ramfb,\(resolution)")

        case .aarch64:
            plan.append("-device", "virtio-gpu-pci,\(resolution)")

        case .x86_64 where usesFramebufferDisplay:
            // Includes a VGA-compatible framebuffer, which also serves guests without a virtio driver.
            plan.append("-device", "virtio-vga,\(resolution)")

        case .x86_64:
            plan.append("-device", "virtio-gpu-pci,\(resolution)")
        }

        plan.append("-device", "qemu-xhci,id=xhci")
        plan.append("-device", "usb-kbd,bus=xhci.0")

        // An absolute pointer keeps the guest cursor aligned with the host cursor
        // without having to capture the mouse.
        plan.append("-device", "usb-tablet,bus=xhci.0")

        plan.append("-device", "virtio-rng-pci")
        plan.append("-device", "virtio-balloon-pci")
    }

    /// Whether the machine boots with the Secure Boot capable firmware.
    var usesSecureBoot: Bool { template.optionalCapabilities.contains(.secureBoot) }

    /// Whether the machine has a TPM 2.0 device.
    var includesTPM: Bool { template.optionalCapabilities.contains(.tpm) }

    /// Whether the display device carries a framebuffer that needs no virtio GPU driver.
    var usesFramebufferDisplay: Bool {
        switch options.displayDevice {
        case .virtioGPU: false
        case .virtioGPUWithFramebuffer: true
        }
    }

    // MARK: - Launch Plan

    /// Validates the template, provisions the files of the machine and builds its launch plan.
    ///
    /// - Returns: The plan to hand to the process controller, and the guards of the external disk
    ///   images it refers to. The plan names files by location only; inside the App Sandbox, the ones
    ///   outside of the application container can be opened just as long as the guards exist.
    /// - Throws: A localized error if the template is not supported or a file cannot be provisioned.
    func createLaunchPlan() throws -> (plan: QEMULaunchPlan, mediaAccess: [SecurityScopedAccess]) {

        try Self.validate(template, options: options, helper: helper)
        try storage.prepareDirectory()

        var plan = QEMULaunchPlan(libraryName: options.architecture.libraryName)

        appendBaseline(to: &plan)
        appendPlatform(to: &plan)
        try appendFirmware(to: &plan)
        appendCoreDevices(to: &plan)
        try appendTPM(to: &plan)
        let mediaAccess = try appendStorage(to: &plan)
        try appendNetwork(to: &plan)
        appendAudio(to: &plan)

        return (plan, mediaAccess)
    }

    // MARK: - Initializers

    /// Creates a builder, locating the helper service and resolving the machine's storage.
    ///
    /// - Parameters:
    ///   - template: The template describing the machine.
    ///   - options: The backend-specific settings.
    /// - Throws: `VZKitError.qemuHelperUnavailable` if the helper service is not embedded.
    init(template: Template, options: QEMUMachineOptions) async throws {
        self.template = template
        self.options = options
        self.helper = try QEMUHelperBundle.locate()
        self.storage = await QEMUMachineStorage(machineID: template.id)
    }
}
