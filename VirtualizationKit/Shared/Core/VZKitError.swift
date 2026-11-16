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
//  VZKitError.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 12/10/24.
//

import Foundation

/// The errors VirtualizationKit throws.
///
/// Every error carries a localized description meant to be shown to the user as is, through
/// `localizedDescription`. Match on the cases to react to a specific failure:
///
/// ```swift
/// do {
///     try await vm.execute(action: .start())
/// } catch VZKitError.unavailableFeature(let capability, .hostSoftware) {
///     offerToInstall(capability)
/// } catch {
///     present(error.localizedDescription)
/// }
/// ```
///
/// Errors raised by Virtualization.framework itself are passed through unchanged, except where a case
/// below says otherwise. Cases may be added in later releases, so a `switch` over this type needs an
/// `@unknown default`.
public enum VZKitError: LocalizedError, Equatable, Sendable {

    // MARK: - Apple backend

    /// The host runs as many macOS virtual machines as the macOS license allows (two at a time).
    case appleLimitExceeded

    /// The auxiliary storage of a macOS virtual machine could not be created.
    case auxiliaryFailedSetup

    /// A disk image could not be created inside the directory of the machine, or could not be attached
    /// to it.
    case diskImageFailedSetup

    /// Virtualization.framework stopped the virtual machine because of an internal error, without saying
    /// which. When it does say, the execution state carries that error instead.
    case internalVirtualizationError

    /// A file that identifies the virtual machine (its machine identifier or hardware model) exists but
    /// cannot be read. The machine has to be recreated.
    case coreFilesTampered

    /// A file that identifies the virtual machine is missing, and cannot be recreated without a restore
    /// image. The machine has to be recreated.
    case coreFilesMissing

    /// macOS cannot be installed because the options refer to no restore image, or to one that cannot be
    /// located anymore.
    case missingMacImage

    /// macOS can only be installed on a virtual machine created for the macOS platform.
    case macPlatformRequired

    /// The restore image offers no configuration this host can run.
    case macUnsupportedImage

    /// The hardware model of the virtual machine cannot run on this host.
    case macUnsupportedHost

    /// The restore image is for a different major macOS version than the one the machine was created for.
    ///
    /// - Parameters:
    ///   - expected: The version the options describe.
    ///   - actual: The version of the restore image.
    case wrongMacImageVersion(_ expected: AppleMachineOptions.Version,
                              _ actual: AppleMachineOptions.Version)

    // MARK: - Storage

    /// An external disk image cannot be located or opened.
    ///
    /// - Parameter name: The file name, when the bookmark could still be resolved to one.
    case diskImageUnreachable(_ name: String?)

    /// Another virtual machine created from the same template is in use, in this application or another one.
    /// Only one machine at a time can use the files of a template.
    case machineInUse

    /// A disk cannot be given a smaller capacity: the guest data beyond it would be lost.
    ///
    /// - Parameter id: The identifier of the disk.
    case cannotShrinkDisk(_ id: UUID)

    /// A disk of the template breaks a rule every backend shares, such as a duplicate identifier or
    /// boot order. The log says which rule.
    ///
    /// - Parameter id: The identifier of the disk.
    case invalidDiskImage(_ id: UUID)

    /// The backend cannot attach a disk of this kind through this interface.
    case unsupportedDiskInterface(_ kind: DiskImage.Kind, _ interface: DiskImage.Interface)

    // MARK: - Capabilities

    /// The backend would provide the capability, but something it depends on is missing.
    case unavailableFeature(_ capability: OptionalCapability, _ missing: CapabilitySupport.MissingComponent)

    /// The user has denied the permission the capability needs, such as access to the microphone.
    case permissionDenied(_ capability: OptionalCapability)

    /// The capability is never provided in this setting. The limitation says why.
    case unsupportedFeature(_ capability: OptionalCapability, _ limitation: CapabilitySupport.Limitation)

    /// The operation needs a capability the virtual machine was created without.
    case featureNotEnabled(_ capability: OptionalCapability)

    /// No removable drive with this identifier is attached to the virtual machine.
    case usbDeviceNotFound(_ id: UUID)

    // MARK: - Networking

    /// A MAC address in the network topology is not valid.
    case invalidMacAddress(_ macAddress: String)

    /// The host network interface to bridge to does not exist.
    ///
    /// - Parameter id: The identifier of the interface, or `nil` when the host has none to bridge to.
    case bridgeNicUnavailable(_ id: String?)

    // MARK: - QEMU backend

    /// The QEMU helper service is not embedded in the application, or cannot be reached.
    case qemuHelperUnavailable

    /// The QEMU helper service failed to prepare or start the emulator.
    case qemuHelperFailure(_ reason: String)

    /// A file of the QEMU payload embedded in the application is missing: an emulator library, a
    /// firmware image or the TPM. The application has to be rebuilt with the complete payload.
    ///
    /// - Parameter name: The name of the file.
    case qemuPayloadMissing(_ name: String)

    /// A file of the virtual machine could not be created or opened.
    case qemuStorageFailedSetup(_ name: String)

    /// The QEMU backend does not support this network topology.
    case qemuUnsupportedNetwork(_ name: String)

    /// The action is not possible in the current execution state.
    ///
    /// - Parameter name: The localized name of the state.
    case qemuInvalidState(_ name: String)

    /// The emulator exited while it was being started or while an operation was in progress.
    ///
    /// - Parameters:
    ///   - status: The exit status.
    ///   - diagnostics: What the emulator printed before exiting.
    case qemuProcessExited(_ status: Int32, _ diagnostics: String)

    /// The emulator rejected a control command, or did not answer it in time.
    case qemuCommandFailed(_ command: String, _ reason: String)

    /// The connection to the display of the guest failed.
    case qemuDisplayFailure(_ reason: String)

    // MARK: - LocalizedError

    /// A localized description of the error, meant to be shown to the user.
    public var errorDescription: String? { self.errorLocale.value }
    
    private var errorLocale: VZKitLocale {
        
        switch self {
        
        case .appleLimitExceeded: .init("error-appleLimitExceeded")
                
        case .auxiliaryFailedSetup: .init("error-auxiliaryFailedSetup")
        case .diskImageFailedSetup: .init("error-diskImageFailedSetup")
        case .coreFilesTampered: .init("error-coreFilesTampered")
        case .coreFilesMissing: .init("error-coreFilesMissing")
        case .missingMacImage: .init("error-missingMacImage")
        case .macPlatformRequired: .init("error-macPlatformRequired")
        case .internalVirtualizationError: .init("error-internalVirtualizationError")

        case .diskImageUnreachable(let name?): .init("error-diskImageUnreachable", name)
        case .diskImageUnreachable(nil): .init("error-diskImageUnreachableGeneric")
        case .machineInUse: .init("error-machineInUse")
        case .cannotShrinkDisk(let id): .init("error-cannotShrinkDisk", id.uuidString)
        case .invalidDiskImage(let id): .init("error-invalidDiskImage", id.uuidString)
        case .unsupportedDiskInterface(let kind, let interface):
            .init("error-unsupportedDiskInterface", kind.localizedName, interface.displayName)
                
        case .permissionDenied(let capability): .init("error-permissionDenied", capability)
        case .featureNotEnabled(let capability): .init("error-featureNotEnabled", capability)

        case .unavailableFeature(let capability, .hostSoftware):
            .init("error-unavailableFeatureHostSoftware", capability)
        case .unavailableFeature(let capability, .frameworkPayload):
            .init("error-unavailableFeatureFrameworkPayload", capability)

        case .unsupportedFeature(let capability, .backend):
            .init("error-unsupportedFeatureBackend", capability)
        case .unsupportedFeature(let capability, .guestPlatform):
            .init("error-unsupportedFeatureGuestPlatform", capability)
        case .unsupportedFeature(let capability, .hostSystem):
            .init("error-unsupportedFeatureHostSystem", capability)
        case .unsupportedFeature(let capability, .hostHardware):
            .init("error-unsupportedFeatureHostHardware", capability)
        case .usbDeviceNotFound(let id): .init("error-usbDeviceNotFound", id.uuidString)
                    
        case .invalidMacAddress(let macAddress): .init("error-invalidMacAddress", macAddress)
        case .bridgeNicUnavailable(let id):
            id != nil ? .init("error-bridgeNicUnavailable", id!) :
                        .init("error-bridgeNoNicsAvailable")
                    
        case .macUnsupportedImage: .init("error-macUnsupportedImage")
        case .macUnsupportedHost: .init("error-macUnsupportedHost")
        case .wrongMacImageVersion(let expected, let actual):
                .init("error-wrongMacImageVersion", expected, actual)
                    
        case .qemuHelperUnavailable: .init("error-qemuHelperUnavailable")
        case .qemuHelperFailure(let reason): .init("error-qemuHelperFailure", reason)
        case .qemuPayloadMissing(let name): .init("error-qemuPayloadMissing", name)
        case .qemuStorageFailedSetup(let name): .init("error-qemuStorageFailedSetup", name)
        case .qemuUnsupportedNetwork(let name): .init("error-qemuUnsupportedNetwork", name)
        case .qemuInvalidState(let name): .init("error-qemuInvalidState", name)
        case .qemuProcessExited(let status, let diagnostics):
                .init("error-qemuProcessExited", String(status), diagnostics)
        case .qemuCommandFailed(let command, let reason):
                .init("error-qemuCommandFailed", command, reason)
        case .qemuDisplayFailure(let reason): .init("error-qemuDisplayFailure", reason)
        }
    }
}
