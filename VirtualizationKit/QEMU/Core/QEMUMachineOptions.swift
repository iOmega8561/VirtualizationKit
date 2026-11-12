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

    // MARK: - Initializers

    /// Creates a set of options.
    ///
    /// - Parameters:
    ///   - architecture: The processor architecture of the guest.
    ///   - displayWidth: The initial display width, in pixels. Clamped to a sensible range.
    ///   - displayHeight: The initial display height, in pixels. Clamped to a sensible range.
    public init(
        architecture: Architecture = .aarch64,
        displayWidth: Int = 1280,
        displayHeight: Int = 720
    ) {
        self.architecture = architecture
        self.displayWidth = min(max(displayWidth, 640), 7680)
        self.displayHeight = min(max(displayHeight, 480), 4320)
    }
}
