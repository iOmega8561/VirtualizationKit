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
/// the template asks for against what this backend can deliver, provisions the files of the machine,
/// and emits a command line that references those files through brokered descriptors only.
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

    /// Rejects templates that ask for something this backend cannot provide.
    ///
    /// Failing here, before anything is launched, yields the same localized errors the Apple backend
    /// reports for unsupported features.
    private func validate() throws {

        switch template.operatingSystem {
        case .linux, .windows: break
        case .macos: throw VZKitError.qemuUnsupportedGuest(template.operatingSystem.displayName)
        }

        for capability in template.optionalCapabilities {
            switch capability {
            case .audioOutputDevice, .xhciUSBHotSwap:
                continue

            case .rosetta, .nestedVirtualization, .directoryShare, .audioCaptureDevice:
                throw VZKitError.unsupportedFeature(capability)
            }
        }

        // Rejected here, before any file is provisioned.
        if case .bridged = template.networkTopology {
            throw VZKitError.qemuUnsupportedNetwork(template.networkTopology.localizedName)
        }

        let library = helper.libraryURL(named: options.architecture.libraryName)

        guard FileManager.default.fileExists(atPath: library.path(percentEncoded: false)) else {
            throw VZKitError.qemuFirmwareMissing(library.lastPathComponent)
        }

        if options.includesTPM {
            let tpm = helper.tpmExecutableURL

            guard FileManager.default.isExecutableFile(atPath: tpm.path(percentEncoded: false)) else {
                throw VZKitError.qemuFirmwareMissing(tpm.lastPathComponent)
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
        // Windows keeps the hardware clock in local time, everything else in UTC.
        plan.append("-rtc", isWindowsGuest ? "base=localtime" : "base=utc")
    }

    /// Emits the machine type, the accelerator and the processor and memory resources.
    private func appendPlatform(to plan: inout QEMULaunchPlan) {

        switch options.architecture {
        case .aarch64:
            plan.append("-machine", "virt")
            plan.append("-accel", "hvf")
            plan.append("-cpu", "host")

        case .x86_64 where options.usesSecureBootFirmware:
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

        let secureBoot = options.usesSecureBootFirmware

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

        let resolution = "xres=\(options.displayWidth),yres=\(options.displayHeight)"

        switch options.architecture {
        case .aarch64 where usesFramebufferDisplay:
            // A virtio GPU that also exposes a RAM framebuffer, which the firmware and Windows' basic
            // display driver use without any driver.
            plan.append("-device", "virtio-ramfb,\(resolution)")

        case .aarch64:
            plan.append("-device", "virtio-gpu-pci,\(resolution)")

        case .x86_64 where options.displayDevice == .virtioGPU:
            plan.append("-device", "virtio-gpu-pci,\(resolution)")

        case .x86_64:
            // Includes a VGA-compatible framebuffer, which also serves guests without a virtio driver.
            plan.append("-device", "virtio-vga,\(resolution)")
        }

        plan.append("-device", "qemu-xhci,id=xhci")
        plan.append("-device", "usb-kbd,bus=xhci.0")

        // An absolute pointer keeps the guest cursor aligned with the host cursor
        // without having to capture the mouse.
        plan.append("-device", "usb-tablet,bus=xhci.0")

        plan.append("-device", "virtio-rng-pci")
        plan.append("-device", "virtio-balloon-pci")
    }

    /// Whether the display device carries a RAM framebuffer in front of the virtio GPU.
    var usesFramebufferDisplay: Bool {
        switch options.displayDevice {
        case .automatic: isWindowsGuest
        case .virtioGPU: false
        case .virtioGPUWithFramebuffer: true
        }
    }

    /// Whether the guest runs Windows, which needs hardware it has drivers for out of the box.
    var isWindowsGuest: Bool {
        if case .windows = template.operatingSystem { true } else { false }
    }

    // MARK: - Launch Plan

    /// Validates the template, provisions the files of the machine and builds its launch plan.
    ///
    /// - Returns: The plan to hand to the process controller.
    /// - Throws: A localized error if the template is not supported or a file cannot be provisioned.
    func createLaunchPlan() throws -> QEMULaunchPlan {

        try validate()
        try storage.prepareDirectory()

        var plan = QEMULaunchPlan(libraryName: options.architecture.libraryName)

        appendBaseline(to: &plan)
        appendPlatform(to: &plan)
        try appendFirmware(to: &plan)
        appendCoreDevices(to: &plan)
        try appendTPM(to: &plan)
        try appendStorage(to: &plan)
        try appendNetwork(to: &plan)
        appendAudio(to: &plan)

        return plan
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
