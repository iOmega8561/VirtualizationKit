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

/// Settings that only make sense for the QEMU backend.
///
/// A template describes a virtual machine in backend-neutral terms. Everything QEMU needs beyond that
/// (which processor architecture to emulate, which graphics device the guest sees) lives here, so the
/// template stays free of anything only one backend understands.
///
/// Every property has a default, and together the defaults describe a Linux guest on Apple silicon:
/// an `aarch64` machine that runs hardware-accelerated through the Hypervisor framework. Nothing is
/// derived from the guest operating system; a guest that needs different hardware, as Windows does
/// before its drivers are installed, is given it explicitly:
///
/// ```swift
/// let windows = QEMUMachineOptions(
///     displayDevice: .virtioGPUWithFramebuffer,
///     clock: .localTime,
///     guestDrawsPointer: true
/// )
/// ```
///
/// ```swift
/// let options = QEMUMachineOptions(architecture: .x86_64)
/// let vm = try await QEMUVirtualMachine(template: template, options: options)
/// ```
public struct QEMUMachineOptions: MachineOptions {

    // MARK: - Supporting Types

    /// The processor architecture of the guest.
    public enum Architecture: String, Transferable, CaseIterable {

        /// 64-bit ARM. Hardware accelerated on Apple silicon hosts.
        case aarch64

        /// 64-bit x86. Always emulated on Apple silicon hosts, and noticeably slower.
        case x86_64

        /// Whether the guest runs through the Hypervisor framework rather than being emulated.
        public var isHardwareAccelerated: Bool {
            switch self {
            case .aarch64: true
            case .x86_64: false
            }
        }

        /// The name of the QEMU system emulator library that implements this architecture.
        var libraryName: String { "qemu-\(rawValue)-softmmu" }
    }

    /// What the hardware clock of the machine counts in.
    public enum Clock: String, Transferable, CaseIterable {

        /// Coordinated Universal Time, which is what Linux and most other guests expect.
        case utc

        /// The local time of the host, which is what Windows expects.
        case localTime
    }

    // MARK: - Properties

    /// The options a virtual machine is created with when none are given: every property at its default.
    public static var `default`: Self { .init() }

    /// The processor architecture of the guest. Defaults to `.aarch64`.
    public var architecture: Architecture

    /// Whether the machine has a TPM 2.0 device. Defaults to `false`.
    ///
    /// The TPM is emulated in software by a separate process next to the emulator, and its state (keys,
    /// counters) is kept in a file of the machine that survives power cycles. Windows 11 requires one,
    /// and any guest can use it for measured boot or disk encryption.
    public var includesTPM: Bool

    /// Whether the machine boots with UEFI firmware that supports Secure Boot. Defaults to `false`.
    ///
    /// The firmware starts without enrolled keys: Secure Boot is available, and can be enabled
    /// from the firmware setup or by the guest, but signatures are not checked until keys are
    /// enrolled. The firmware keeps its settings in a variable store of its own, so changing this
    /// option makes the machine start with fresh firmware settings (boot entries included).
    public var usesSecureBootFirmware: Bool

    /// The graphics device the guest sees. Defaults to `.virtioGPU`.
    public var displayDevice: DisplayDevice

    /// What the hardware clock of the machine counts in. Defaults to `.utc`.
    public var clock: Clock

    /// Whether the guest draws its pointer into the picture itself until it defines a pointer image.
    /// Defaults to `false`.
    ///
    /// A guest without a driver for the virtio GPU (Windows, before the virtio drivers are installed)
    /// never hands over a pointer image; its pointer is part of every frame. With this set, the
    /// framebuffer view hides the host pointer over the display instead of showing a second one on top.
    /// Once the guest does define a pointer image, that image is shown as usual.
    public var guestDrawsPointer: Bool

    /// The graphics devices a machine can have.
    public enum DisplayDevice: String, Transferable, CaseIterable {

        /// A virtio GPU only. The guest needs a virtio GPU driver to show anything once it has started:
        /// Linux has one built in, Windows once the virtio drivers are installed. The firmware and
        /// boot loaders draw through it as well, but Windows' boot screens may stay black until its
        /// driver loads.
        case virtioGPU

        /// A virtio GPU with a plain RAM framebuffer in front, which guests without a virtio GPU driver
        /// can draw to (Windows during and after setup, before the virtio drivers are installed).
        ///
        /// Once a virtio GPU driver is running, the guest sees **two** displays: the framebuffer and the
        /// virtio GPU. Only the virtio GPU is shown, so parts of the desktop end up on the hidden display
        /// and pointer positions span both. Switch to `.virtioGPU` after installing the driver.
        ///
        /// On x86_64 the framebuffer is part of the virtio GPU itself (a VGA-compatible one), so the
        /// guest only ever sees one display.
        case virtioGPUWithFramebuffer
    }

    // MARK: - Initializers

    /// Creates a set of options.
    ///
    /// - Parameters:
    ///   - architecture: The processor architecture of the guest.
    ///   - includesTPM: Whether the machine has a TPM 2.0 device.
    ///   - usesSecureBootFirmware: Whether the machine boots with Secure Boot capable firmware.
    ///   - displayDevice: The graphics device the guest sees.
    ///   - clock: What the hardware clock of the machine counts in.
    ///   - guestDrawsPointer: Whether the guest draws its pointer into the picture itself.
    public init(
        architecture: Architecture = .aarch64,
        includesTPM: Bool = false,
        usesSecureBootFirmware: Bool = false,
        displayDevice: DisplayDevice = .virtioGPU,
        clock: Clock = .utc,
        guestDrawsPointer: Bool = false
    ) {
        self.architecture = architecture
        self.includesTPM = includesTPM
        self.usesSecureBootFirmware = usesSecureBootFirmware
        self.displayDevice = displayDevice
        self.clock = clock
        self.guestDrawsPointer = guestDrawsPointer
    }

    // MARK: - Codable

    /// The keys of the encoded form.
    private enum CodingKeys: String, CodingKey {
        case architecture, includesTPM, usesSecureBootFirmware, displayDevice, clock, guestDrawsPointer
    }

    /// The encoded form of the display device that 1.x picked from the guest operating system.
    private static let legacyAutomaticDisplayDevice = "automatic"

    /// Decodes a set of options.
    ///
    /// Options encoded before a property existed decode with that property's default, so options an
    /// application has stored keep working when it adopts a newer framework.
    ///
    /// Options stored by 1.x may name the `automatic` display device, which picked a device from the
    /// guest operating system and no longer exists. It decodes to what it resolved to for every guest
    /// but one: `.virtioGPU` on aarch64 and `.virtioGPUWithFramebuffer` on x86_64. The exception is
    /// Windows on aarch64, which used the framebuffer variant and has to ask for it explicitly now.
    ///
    /// - Parameter decoder: The decoder to read from.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let architecture = try container.decodeIfPresent(Architecture.self, forKey: .architecture) ?? .aarch64
        let displayDevice: DisplayDevice

        switch try container.decodeIfPresent(String.self, forKey: .displayDevice) {
        case nil:
            displayDevice = .virtioGPU

        case Self.legacyAutomaticDisplayDevice?:
            displayDevice = architecture == .aarch64 ? .virtioGPU : .virtioGPUWithFramebuffer

        case let name?:
            guard let device = DisplayDevice(rawValue: name) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .displayDevice,
                    in: container,
                    debugDescription: "Unknown display device “\(name)”"
                )
            }
            displayDevice = device
        }

        self.init(
            architecture: architecture,
            includesTPM: try container.decodeIfPresent(Bool.self, forKey: .includesTPM) ?? false,
            usesSecureBootFirmware: try container.decodeIfPresent(Bool.self, forKey: .usesSecureBootFirmware) ?? false,
            displayDevice: displayDevice,
            clock: try container.decodeIfPresent(Clock.self, forKey: .clock) ?? .utc,
            guestDrawsPointer: try container.decodeIfPresent(Bool.self, forKey: .guestDrawsPointer) ?? false
        )
    }
}
