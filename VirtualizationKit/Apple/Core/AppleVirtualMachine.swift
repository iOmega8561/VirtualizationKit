//
//  Copyright 2025 Giuseppe Rocco
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
//  -----------------------------------------------------------------------
//
//  AppleVirtualMachine.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 15/05/24.
//

import Virtualization

/// A specialized struct implementing `VirtualMachine` for the Apple Virtualization framework.
///
/// `AppleVirtualMachine` is a small value that refers to the components of a machine. Copies refer to the
/// same machine, so it can be passed around freely; it is `Sendable`.
///
/// ## Concurrency
/// Virtualization.framework requires every operation on a machine to happen on the queue the machine was
/// created with. The machine is owned by an `AppleMachineHandle`, isolated to `VZKitActor`, whose executor
/// is that queue: the compiler rejects any use of the machine from elsewhere. `execute(action:)` and the
/// removable-drive methods run on `VZKitActor` as well.
///
/// ## Components
/// - **`template`**: The description of the machine every backend shares (memory, CPU, storage, etc.),
///   provided by user-defined types conforming to `TransferableTemplate`.
/// - **`options`**: What only this backend understands: the platform the guest runs on.
/// - **`stateCoordinator`**: The execution state (`ExecutionState`), on the main actor, for user interfaces.
///   It follows what the machine reports, through the observation of its state and through its delegate.
/// - **`handle`** (internal): The `VZVirtualMachine`, its operations, and the connection to framebuffer views.
/// - **`errorDelegate`** (internal): Receives the error that stopped the machine and reports it to
///   `stateCoordinator`.
/// - **`resources`** (internal): Keeps files outside the application container reachable.
public struct AppleVirtualMachine<Template: TransferableTemplate>: VirtualMachine {
    
    /// An enum of high-level actions that can be performed on the Apple Virtual Machine.
    ///
    /// Examples include:
    /// - `.start(options: ... )`: Boot the VM using the specified launch options.
    /// - `.stop`: Power the VM off at once, without involving the guest.
    /// - `.requestStop`: Ask the guest to shut itself down, as pressing the power button would.
    /// - `.pause`: Suspend the VM.
    /// - `.resume`: Resume the VM from a paused state.
    /// - `.install`: Install macOS from the restore image the options refer to. macOS guests only.
    public enum Action: ExecutableAction {
        case start(options: AppleStartOptions?)
        case stop
        case requestStop
        case pause
        case resume
        case install
    }
    
    /// The configuration template describing how to set up and manage the VM.
    ///
    /// `template` should contain details such as memory allocation, CPU cores, disk images,
    /// and any other configuration data relevant to the virtual machine. It must conform
    /// to `TransferableTemplate`.
    public let template: Template
    
    /// The settings only this backend understands, such as the platform the guest runs on.
    ///
    /// Together with `template`, they identify the machine: persist the two side by side.
    public let options: AppleMachineOptions

    /// Manages the VM’s execution state and communicates changes on the main actor.
    ///
    /// `stateCoordinator` tracks `ExecutionState` updates and provides Combine publishers
    /// for consumers such as SwiftUI views. Its `@MainActor` isolation ensures state changes
    /// are safe for UI binding.
    public let stateCoordinator: AppleStateCoordinator
    
    /// Owns the Apple Virtualization object responsible for lifecycle operations, and keeps every use of
    /// it on the machine's queue. Shared by all copies of this value.
    let handle: AppleMachineHandle
    
    /// The delegate of the `VZVirtualMachine`.
    ///
    /// It receives the error that stopped the machine and reports it to `stateCoordinator`. A network
    /// attachment that disconnects is only logged: the machine keeps running.
    private let errorDelegate: AppleErrorDelegate
    
    /// Keeps external disk images and the macOS restore image reachable inside the App Sandbox for as
    /// long as the machine exists.
    ///
    /// They are referenced by the configuration (as attached images) and by the macOS installer, both of
    /// which open them long after this value has been created.
    private let resources: AppleMachineResources

    /// The location of the macOS restore image, when the template refers to one that could be located.
    var restoreImageURL: URL? { resources.restoreImage?.url }
    
    /// Keeps the images of hot-plugged removable devices reachable while they are attached.
    private let removableMediaAccess: SecurityScopeRegistry
    
    /// Executes a high-level action on the machine's queue.
    ///
    /// The method returns once Virtualization.framework has completed the operation. It does not change the
    /// execution state itself: the state follows what the machine reports, so it may be updated a moment
    /// after the method returns.
    ///
    /// - Parameter action: The requested operation; see `Action`.
    /// - Throws:
    ///   - `VZKitError.appleLimitExceeded` if the host runs as many macOS virtual machines as it allows.
    ///   - `VZKitError.macPlatformRequired` or `VZKitError.missingMacImage` for `.install`, if the machine is
    ///     not a macOS guest, or its restore image cannot be located.
    ///   - The errors of Virtualization.framework otherwise, unchanged.
    @VZKitActor public func execute(action: Action) async throws {
        // Failures propagate unchanged, except one. The state needs no repair here: it follows what the
        // machine reports, through the observation of its state and through its delegate.
        do {
            switch action {
            case .start(let options):
                try await handle.start(fromRecovery: options?.startsFromRecovery ?? false)
            case .stop:
                try await handle.stop()
            case .requestStop:
                try handle.requestStop()
            case .pause:
                try await handle.pause()
            case .resume:
                try await handle.resume()
            case .install:
                guard case .macOS = options.platform else { throw VZKitError.macPlatformRequired }
                guard let restoreImage = restoreImageURL else { throw VZKitError.missingMacImage }
                try await handle.installMacOS(from: restoreImage, reportingTo: stateCoordinator)
            }
        } catch VZError.virtualMachineLimitExceeded {
            
            if await self.executionState != .stopped {
                // Note:
                //
                // Historically, `VZVirtualMachine` would automatically transition to `.stopped`
                // after termination, and this state change would propagate via KVO observation.
                // In recent macOS versions, this no longer occurs — the VM state appears to
                // remain stuck in its last transitional state even after the VM has fully stopped.
                // The cause is unclear; it may be a change in Virtualization.framework's internal state
                // management or a regression in macOS.
                //
                // Workaround: explicitly reset the execution state here to keep the coordinator
                // in sync with the actual VM state.
                await self.stateCoordinator.resetExecutionState()
            }

            throw VZKitError.appleLimitExceeded
        }
    }

    /// Tells whether this backend can provide an optional capability.
    ///
    /// The answer depends on the platform the options select and on the host: Rosetta, for instance, is
    /// offered to Linux guests only, and is unavailable until it has been installed on the host.
    ///
    /// - Parameters:
    ///   - capability: The capability in question.
    ///   - options: The options the virtual machine would be created with.
    /// - Returns: Whether the capability is supported, never provided, or unavailable for the time being.
    public static func support(
        for capability: OptionalCapability,
        options: AppleMachineOptions
    ) -> CapabilitySupport {
        AppleConfigurationBuilder<Template>.support(for: capability, on: options.platform)
    }

    /// Checks whether a virtual machine can be created from a template and a set of options, without
    /// creating or modifying anything on disk.
    ///
    /// - Parameters:
    ///   - template: The configuration object that describes how the virtual machine should be built.
    ///   - options: The options the virtual machine would be created with.
    /// - Throws: A localized error naming the first thing this backend cannot honour.
    public static func validate(_ template: Template, options: AppleMachineOptions) throws {
        try AppleConfigurationBuilder.validate(template, options: options)
    }

    /// Creates a virtual machine.
    ///
    /// The template and the options are validated first; a description this backend cannot honour is rejected
    /// before anything is written to disk. Then the files of the machine are located or created, the
    /// configuration is assembled, and the `VZVirtualMachine` is created on its queue.
    ///
    /// - Parameters:
    ///   - template: The configuration object that describes how the virtual machine should be built.
    ///   - options: The settings only this backend understands. `init(template:)` passes the default,
    ///     which describes a Linux guest.
    /// - Throws: A localized error if the description is not valid for this backend, or if a file of the
    ///   machine cannot be located or created; the errors of Virtualization.framework otherwise.
    public init(template: Template, options: AppleMachineOptions) async throws {
        
        self.removableMediaAccess = .init()
        
        let builder = await AppleConfigurationBuilder(template: template, options: options)
        let (configuration, resources) = try await builder.createConfiguration()
        let errorDelegate = AppleErrorDelegate()
        
        self.resources = resources

        self.handle = await AppleMachineHandle(
            configuration: configuration,
            delegate: errorDelegate
        )
        
        self.errorDelegate = errorDelegate
        self.template = template
        self.options = options
        self.stateCoordinator = await .init()
        
        await self.stateCoordinator.subscribe(errorDelegate.errorSubject)

        // A new machine is always stopped, so the first value is supplied here, and only real changes
        // are observed. The observation starts after the coordinator subscribed, on the machine's queue.
        await self.stateCoordinator.subscribe(handle.stateChanges.prepend(.stopped))
        await handle.startObservingState()
    }
}

@VZKitActor extension AppleVirtualMachine {

    /// The Apple Virtualization object, on the machine's queue.
    var vzVirtualMachine: VZVirtualMachine { handle.machine }
}

@VZKitActor public extension AppleVirtualMachine {
    
    /// Attaches a removable drive to the running virtual machine, as a USB mass storage device.
    ///
    /// The drive is attached read-only, to the USB controller of the machine.
    ///
    /// - Parameter url: The location of the disk image.
    /// - Returns: An identifier for the drive, to pass to `detachRemovableDrive(identifiedBy:)`.
    /// - Throws:
    ///   - `VZKitError.unsupportedFeature(.xhciUSBHotSwap, .hostSystem)` before macOS 15.
    ///   - `VZKitError.featureNotEnabled(.xhciUSBHotSwap)` if the machine was created without the capability.
    ///   - Other Apple Virtualization–related errors if attachment fails.
    func attachRemovableDrive(imageAt url: URL) async throws -> UUID {

        try checkRemovableDriveSupport()

        // Unreachable before macOS 15, which the check above turns away. Required by the compiler.
        guard #available(macOS 15.0, *) else {
            throw VZKitError.unsupportedFeature(.xhciUSBHotSwap, .hostSystem)
        }

        let controller = try removableDriveController()

        // Released again if anything below throws, kept for as long as the device stays attached.
        let access = SecurityScopedAccess(url: url)
        
        let massStorageDev = try VZUSBMassStorageDevice(
            configuration: .create(at: url, type: .readOnly)
        )
        
        try await handle.attach(massStorageDev, to: controller)
        removableMediaAccess.retain(access, for: massStorageDev.uuid)
        return massStorageDev.uuid
    }
    
    /// Detaches a drive attached with `attachRemovableDrive(imageAt:)`.
    ///
    /// - Parameter id: The identifier returned when the drive was attached.
    /// - Throws:
    ///   - `VZKitError.unsupportedFeature(.xhciUSBHotSwap, .hostSystem)` before macOS 15.
    ///   - `VZKitError.featureNotEnabled(.xhciUSBHotSwap)` if the machine was created without the capability.
    ///   - `VZKitError.usbDeviceNotFound(id)` if the specified drive is not attached.
    ///   - Other errors originating from the Apple Virtualization framework during detachment.
    func detachRemovableDrive(identifiedBy id: UUID) async throws {

        try checkRemovableDriveSupport()

        // Unreachable before macOS 15, which the check above turns away. Required by the compiler.
        guard #available(macOS 15.0, *) else {
            throw VZKitError.unsupportedFeature(.xhciUSBHotSwap, .hostSystem)
        }

        let controller = try removableDriveController()

        guard let device = controller.usbDevices.first(where: { $0.uuid == id }) else {
            throw VZKitError.usbDeviceNotFound(id)
        }
        
        try await handle.detach(device, from: controller)
        removableMediaAccess.release(id)
    }

    /// Checks that removable drives can be used: first the host, then the machine.
    ///
    /// The host is checked through the support table, the same answer validation gives, so the error
    /// names the same reason ("requires a newer version of macOS"). The machine needs the capability,
    /// because its USB controller exists only if the template asked for it.
    private func checkRemovableDriveSupport() throws {

        try Self.support(for: .xhciUSBHotSwap, options: options).check(.xhciUSBHotSwap)

        guard template.optionalCapabilities.contains(.xhciUSBHotSwap) else {
            throw VZKitError.featureNotEnabled(.xhciUSBHotSwap)
        }
    }

    /// The USB controller removable drives are attached to.
    @available(macOS 15.0, *)
    private func removableDriveController() throws -> VZUSBController {

        guard let controller = vzVirtualMachine.usbControllers.first else {
            throw VZKitError.featureNotEnabled(.xhciUSBHotSwap)
        }

        return controller
    }
}
