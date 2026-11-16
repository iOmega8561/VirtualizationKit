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

/// A virtual machine backed by QEMU.
///
/// `QEMUVirtualMachine` is the counterpart of the Apple-backed machine and is used the same way: it is
/// created from a template, exposes a state coordinator, and is driven through `execute(action:)`.
///
/// ```swift
/// let vm = try await QEMUVirtualMachine(template: template)
/// try await vm.execute(action: .start())
/// ```
///
/// What differs is where the guest runs. The emulator is not part of the application process: it is
/// hosted by a sandboxed helper service that ships with the framework, and this type merely holds the
/// connection to it. Creating a machine validates the template and provisions its files, but starts
/// nothing; the emulator process exists from `.start` until the guest powers off or `.stop` is executed.
///
/// ## Concurrency
/// Like its Apple counterpart this is a lightweight, `Sendable` value that can be copied freely. All
/// copies refer to the same engine, which serializes the actions executed on the machine.
public struct QEMUVirtualMachine<Template: TransferableTemplate>: VirtualMachine {

    /// The high-level actions that can be performed on a QEMU virtual machine.
    ///
    /// - `.start(options:)`: Power the machine on.
    /// - `.stop`: Power the machine off without involving the guest.
    /// - `.requestStop`: Press the virtual power button, asking the guest to shut itself down.
    /// - `.reset`: Restart the machine at once, as the reset button of a physical one would. The guest is
    ///   not involved, so it can lose data it has not written yet; the state does not change.
    /// - `.pause`: Halt the guest processors.
    /// - `.resume`: Let a paused guest run again.
    public enum Action: ExecutableAction {
        case start(options: QEMUStartOptions?)
        case stop
        case requestStop
        case reset
        case pause
        case resume
    }

    /// The configuration template describing the machine.
    public let template: Template

    /// The backend-specific settings the machine was created with.
    public let options: QEMUMachineOptions

    /// Tracks the execution state of the machine and broadcasts its changes on the main actor.
    public let stateCoordinator: QEMUStateCoordinator

    /// Drives the emulator process. Shared by all copies of this value.
    let engine: QEMUEngine

    /// The guest display, shown by `QEMUFramebufferView`. Shared by all copies of this value.
    let display: QEMUDisplay

    /// Keeps external disk images reachable inside the App Sandbox for as long as the machine exists.
    ///
    /// The images are opened at every power-on, long after this value has been created.
    private let mediaAccess: [SecurityScopedAccess]

    /// Executes a high-level action.
    ///
    /// - Parameter action: The requested operation.
    /// - Throws: A localized error if the action is not possible in the current state, if the helper
    ///   service is unavailable, or if the emulator fails. When the emulator exits during start-up,
    ///   the error carries the diagnostics it printed.
    public func execute(action: Action) async throws {
        switch action {
        case .start(let options):
            try await engine.start(paused: options?.startsPaused ?? false)
        case .stop:
            try await engine.stop()
        case .requestStop:
            try await engine.requestPowerDown()
        case .reset:
            try await engine.reset()
        case .pause:
            try await engine.pause()
        case .resume:
            try await engine.resume()
        }
    }

    /// Tells whether this backend can provide an optional capability.
    ///
    /// A TPM and Secure Boot depend on files of the emulator payload and are reported as unavailable
    /// when the payload was built without them, or when the helper service is not embedded at all.
    ///
    /// - Parameters:
    ///   - capability: The capability in question.
    ///   - options: The options the machine would be created with.
    /// - Returns: Whether the capability is supported, never provided, or unavailable for the time being.
    public static func support(
        for capability: OptionalCapability,
        options: QEMUMachineOptions
    ) -> CapabilitySupport {
        QEMUConfigurationBuilder<Template>.support(
            for: capability,
            options: options,
            helper: try? QEMUHelperBundle.locate()
        )
    }

    /// Checks whether a machine can be created from a template and a set of options, without creating
    /// or modifying anything on disk.
    ///
    /// - Parameters:
    ///   - template: The template describing the machine.
    ///   - options: The options the machine would be created with.
    /// - Throws: A localized error if the template asks for something this backend does not support,
    ///   or if the helper service is not embedded.
    public static func validate(_ template: Template, options: QEMUMachineOptions) throws {
        try QEMUConfigurationBuilder.validate(
            template,
            options: options,
            helper: try QEMUHelperBundle.locate()
        )
    }

    /// Creates a machine.
    ///
    /// - Parameters:
    ///   - template: The template describing the machine.
    ///   - options: The backend-specific settings, such as the guest architecture. `init(template:)`
    ///     passes the default, which describes an `aarch64` Linux guest.
    /// - Throws: A localized error if the template asks for something this backend does not support,
    ///   if the helper service is not embedded, or if the files of the machine cannot be provisioned.
    public init(template: Template, options: QEMUMachineOptions) async throws {

        let builder = try await QEMUConfigurationBuilder(template: template, options: options)
        let (plan, mediaAccess) = try builder.createLaunchPlan()
        let stateCoordinator = await QEMUStateCoordinator()
        let display = await QEMUDisplay(guestDrawsPointer: options.guestDrawsPointer)

        self.template = template
        self.options = options
        self.mediaAccess = mediaAccess
        self.stateCoordinator = stateCoordinator
        self.display = display
        self.engine = .init(
            plan: plan,
            helper: builder.helper,
            coordinator: stateCoordinator,
            display: display
        )
    }
}

public extension QEMUVirtualMachine {

    /// Attaches a removable USB drive backed by a disk image to the running machine.
    ///
    /// The image is opened read-only by the application and handed to the emulator as an open file, so
    /// a user-selected file outside of the sandbox container works as long as the URL carries its
    /// security scope. Access stays active while the drive is attached.
    ///
    /// A disc image (ISO 9660 or UDF, including hybrid images) is attached as a USB CD-ROM drive,
    /// anything else as a USB disk. Windows in particular only reads disc images from a CD-ROM drive.
    ///
    /// Like on the Apple backend, the machine has to be created with the `.xhciUSBHotSwap` capability.
    ///
    /// - Parameter url: A file URL referencing the disk image to attach.
    /// - Returns: A `UUID` identifying the attached drive, for later removal.
    /// - Throws: `VZKitError.featureNotEnabled(.xhciUSBHotSwap)` if the machine was created without the
    ///   capability, or a localized error if the machine is not running, the image cannot be opened, or
    ///   the emulator rejects the drive.
    func attachRemovableDrive(imageAt url: URL) async throws -> UUID {
        try Self.checkRemovableDriveSupport(in: template)
        return try await engine.attachRemovableDisk(at: url)
    }

    /// Detaches a removable USB drive attached with `attachRemovableDrive(imageAt:)`.
    ///
    /// Returns once the guest has let go of the drive.
    ///
    /// - Parameter id: The `UUID` returned when the drive was attached.
    /// - Throws: `VZKitError.featureNotEnabled(.xhciUSBHotSwap)` if the machine was created without the
    ///   capability, `VZKitError.usbDeviceNotFound(id)` if no such drive is attached, or a localized error
    ///   if the emulator does not release it.
    func detachRemovableDrive(identifiedBy id: UUID) async throws {
        try Self.checkRemovableDriveSupport(in: template)
        try await engine.detachRemovableDisk(identifiedBy: id)
    }

    /// Checks that a machine described by a template may use removable drives.
    ///
    /// The USB controller exists on every QEMU machine, because the keyboard and the pointer are
    /// attached to it. Drives still need the capability, so that a template means the same on both
    /// backends: generic code gets the same answer whichever one runs the machine.
    ///
    /// - Parameter template: The template of the machine.
    /// - Throws: `VZKitError.featureNotEnabled(.xhciUSBHotSwap)` without the capability.
    internal static func checkRemovableDriveSupport(in template: Template) throws {
        guard template.optionalCapabilities.contains(.xhciUSBHotSwap) else {
            throw VZKitError.featureNotEnabled(.xhciUSBHotSwap)
        }
    }

    /// The last failure of the guest display, if any.
    ///
    /// A display failure does not stop the machine: the guest keeps running, only the framebuffer
    /// views stay empty. The value is cleared when the machine is powered on again.
    @MainActor
    var displayFailure: (any Error)? {
        display.failure
    }
}
