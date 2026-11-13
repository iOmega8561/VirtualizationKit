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
/// (which processor architecture to emulate, how large the display is at power-on) lives here, so the
/// template protocol stays untouched and existing templates keep working with both backends.
///
/// Every property has a default that "just works" on Apple silicon:
/// an `aarch64` guest runs hardware-accelerated through the Hypervisor framework.
///
/// ```swift
/// let options = QEMUMachineOptions(architecture: .x86_64)
/// let vm = try await QEMUVirtualMachine(template: template, options: options)
/// ```
public struct QEMUMachineOptions: Transferable {

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

    // MARK: - Properties

    /// The processor architecture of the guest. Defaults to `.aarch64`.
    public var architecture: Architecture

    /// The width of the guest display at power-on, in pixels.
    ///
    /// The guest is free to change its resolution later, and the framebuffer view can ask it to follow
    /// the size of its container.
    public var displayWidth: Int

    /// The height of the guest display at power-on, in pixels.
    public var displayHeight: Int

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

    /// The graphics device the guest sees. Defaults to `.automatic`.
    public var displayDevice: DisplayDevice

    /// The graphics devices a machine can have.
    public enum DisplayDevice: String, Transferable, CaseIterable {

        /// The device that suits the guest operating system: a virtio GPU with a RAM framebuffer for
        /// Windows on aarch64 (`.virtioGPUWithFramebuffer`), a virtio GPU otherwise (`.virtioGPU`).
        case automatic

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
        /// guest only ever sees one display and both cases are the same device.
        case virtioGPUWithFramebuffer
    }

    // MARK: - Initializers

    /// Creates a set of options.
    ///
    /// - Parameters:
    ///   - architecture: The processor architecture of the guest.
    ///   - displayWidth: The initial display width, in pixels. Clamped to a sensible range.
    ///   - displayHeight: The initial display height, in pixels. Clamped to a sensible range.
    ///   - includesTPM: Whether the machine has a TPM 2.0 device.
    ///   - usesSecureBootFirmware: Whether the machine boots with Secure Boot capable firmware.
    public init(
        architecture: Architecture = .aarch64,
        displayWidth: Int = 1280,
        displayHeight: Int = 720,
        includesTPM: Bool = false,
        usesSecureBootFirmware: Bool = false,
        displayDevice: DisplayDevice = .automatic
    ) {
        self.architecture = architecture
        self.displayWidth = min(max(displayWidth, 640), 7680)
        self.displayHeight = min(max(displayHeight, 480), 4320)
        self.includesTPM = includesTPM
        self.usesSecureBootFirmware = usesSecureBootFirmware
        self.displayDevice = displayDevice
    }

    // MARK: - Codable

    /// The keys of the encoded form.
    private enum CodingKeys: String, CodingKey {
        case architecture, displayWidth, displayHeight, includesTPM, usesSecureBootFirmware, displayDevice
    }

    /// Decodes a set of options.
    ///
    /// Options encoded before a property existed decode with that property's default, so options an
    /// application has stored keep working when it adopts a newer framework.
    ///
    /// - Parameter decoder: The decoder to read from.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.init(
            architecture: try container.decodeIfPresent(Architecture.self, forKey: .architecture) ?? .aarch64,
            displayWidth: try container.decodeIfPresent(Int.self, forKey: .displayWidth) ?? 1280,
            displayHeight: try container.decodeIfPresent(Int.self, forKey: .displayHeight) ?? 720,
            includesTPM: try container.decodeIfPresent(Bool.self, forKey: .includesTPM) ?? false,
            usesSecureBootFirmware: try container.decodeIfPresent(Bool.self, forKey: .usesSecureBootFirmware) ?? false,
            displayDevice: try container.decodeIfPresent(DisplayDevice.self, forKey: .displayDevice) ?? .automatic
        )
    }
}
