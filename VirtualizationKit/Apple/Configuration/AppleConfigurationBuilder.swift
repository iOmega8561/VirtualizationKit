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
//  AppleConfigBuilder.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 17/05/24.
//

import Virtualization

/// `VZKitBuilder` data structure
///
/// This struct embodies the resolution of a builder pattern, aimed to provide a full fledged
/// `VZVirtualMachineConfiguration` object starting from a simple template
///
/// - Important: `VZVirtualMachineConfiguration` IS NOT sendable.
///   We import the `Virtualization` framework using `@preconcurrency`.
struct AppleConfigurationBuilder<Template: TransferableTemplate> {
    
    /// A copy of the DTO to have all the necessary info about the VM template
    let template: Template
    
    /// The settings only this backend understands, such as the platform the guest runs on
    let options: AppleMachineOptions

    /// Reference to the native `Virtualization` framework configuration object
    let configuration: VZVirtualMachineConfiguration
    
    /// Stored property to get the location of the VM's storage folder inside the application bundle
    private let vmSupportDirectory: URL
    
    /// This method is responsible of building the full fledged virtual machine configuration scheme.
    /// To do that it makes a distinction between the different guest platforms, since they need completely different
    /// configuration schemes. Its workings are helped by the several static factory methods implemented for every virtual device.
    /// It also creates the VM folder if the latter doesn't exist already.
    ///
    /// - Parameters:
    ///   - image: The macOS restore image object, if needed.
    ///   - disks: The disks of the template, located on the host, in the order they are presented in.
    private func createConfiguration(
        using restoreImage: VZMacOSRestoreImage?,
        disks: [ProvisionedDiskImage]
    ) async throws {
        
        switch options.platform {
        case .macOS:
            
            configuration.platform = try .create(
                at: vmSupportDirectory,
                type: .macintosh(restoreImage: restoreImage)
            )
            
            configuration.bootLoader = try .create()
            
        case .linux:
            
            configuration.platform = try .create(
                at: vmSupportDirectory,
                type: .generic(nestedVirtualization: template.optionalCapabilities.contains(.nestedVirtualization))
            )
            
            configuration.bootLoader = try .create(
                at: vmSupportDirectory.appendingPathComponent("NVRAM")
            )
            
            if template.optionalCapabilities.contains(.rosetta) {
                configuration.directorySharingDevices.append(try VZLinuxRosettaDirectoryShare.create())
            }
        }
      
        for disk in disks {
            configuration.storageDevices.append(try VZStorageDeviceConfiguration.create(for: disk))
        }
        
        configuration.consoleDevices.append(.create(type: options.platform))
        configuration.graphicsDevices.append(.create(type: (options.platform, template.display)))
        configuration.keyboards.append(.create(type: options.platform))
        configuration.pointingDevices.append(.create(type: options.platform))
        configuration.networkDevices.append(try .create(type: template.networkTopology))
        configuration.cpuCount = template.performancePreset.cpuCoreCount
        configuration.memorySize = template.performancePreset.memorySize
        configuration.memoryBalloonDevices.append(VZVirtioTraditionalMemoryBalloonDeviceConfiguration())
        configuration.entropyDevices.append(VZVirtioEntropyDeviceConfiguration())
        
        if template.optionalCapabilities.contains(.audioOutputDevice) {
            configuration.audioDevices.append(try await .create(type: .output))
        }
        
        if template.optionalCapabilities.contains(.audioCaptureDevice) {
            configuration.audioDevices.append(try await .create(type: .input))
        }
        
        if template.optionalCapabilities.contains(.directoryShare) {
            configuration.directorySharingDevices.append(
                try .create(
                    at: vmSupportDirectory.appendingPathComponent(template.name),
                    type: options.platform
                )
            )
        }

        // Hosts older than macOS 15 are turned away by the validation.
        if #available(macOS 15.0, *), template.optionalCapabilities.contains(.xhciUSBHotSwap) {
            configuration.usbControllers.append(VZXHCIControllerConfiguration())
        }
    }

    /// Tells whether this backend can provide an optional capability to a guest of a given platform.
    ///
    /// The single source of truth for capabilities: `validate` acts on the same answer. There is
    /// deliberately no `default`, so a capability added to the framework does not compile until this
    /// backend has an answer for it.
    ///
    /// - Note: Capturing audio also needs the consent of the user. Asking for it shows a prompt, so it is
    ///   left to the moment the device is created.
    ///
    /// - Parameters:
    ///   - capability: The capability in question.
    ///   - platform: The platform the guest runs on.
    /// - Returns: Whether the capability is supported, never provided, or unavailable for the time being.
    static func support(
        for capability: OptionalCapability,
        on platform: AppleMachineOptions.Platform
    ) -> CapabilitySupport {

        switch (capability, platform) {
        case (.rosetta, .linux):

            switch VZLinuxRosettaDirectoryShare.availability {
            case .installed: return .supported
            case .notInstalled: return .unavailable(.hostSoftware)
            // Rosetta does not exist on Macs with Intel processors.
            case .notSupported: return .unsupported(.hostHardware)
            @unknown default: return .unsupported(.hostHardware)
            }

        case (.rosetta, .macOS), (.nestedVirtualization, .macOS):
            return .unsupported(.guestPlatform)

        case (.nestedVirtualization, .linux):
            guard #available(macOS 15.0, *) else { return .unsupported(.hostSystem) }
            // Needs an M3 or later.
            return VZGenericPlatformConfiguration.isNestedVirtualizationSupported
                ? .supported
                : .unsupported(.hostHardware)

        case (.xhciUSBHotSwap, _):
            if #available(macOS 15.0, *) { return .supported }
            return .unsupported(.hostSystem)

        case (.directoryShare, .linux):
            return .supported

        case (.directoryShare, .macOS(let version, _)):
            // macOS 12 has no driver for the automount tag.
            return version.major > 12 ? .supported : .unsupported(.guestPlatform)

        case (.audioOutputDevice, _), (.audioCaptureDevice, _):
            return .supported

        case (.tpm, _), (.secureBoot, _):
            return .unsupported(.backend)
        }
    }

    /// Rejects templates that ask for something this backend cannot provide.
    ///
    /// Everything that can be told from the template and the options alone is checked here: the optional
    /// capabilities and the disks. Nothing is created or modified on disk.
    ///
    /// - Parameters:
    ///   - template: The data transfer object containing all the info about the virtual machine.
    ///   - options: The settings only this backend understands.
    static func validate(_ template: Template, options: AppleMachineOptions) throws {

        for capability in template.optionalCapabilities {
            try support(for: capability, on: options.platform).check(capability)
        }

        try validateStorage(template.storage, on: options.platform)
    }

    /// Checks the disks of a template against what this backend can attach, without touching the
    /// file system.
    ///
    /// On top of the rules every backend shares, Virtualization.framework only offers NVMe
    /// controllers to Linux guests.
    private static func validateStorage(
        _ storage: [DiskImage],
        on platform: AppleMachineOptions.Platform
    ) throws {

        try DiskImage.validate(storage)

        for disk in storage {

            switch disk.format {
            case .raw: break
            }

            switch (disk.interface, platform) {
            case (.virtio, _), (.usb, _), (.nvme, .linux): break
            case (.nvme, .macOS):
                throw VZKitError.unsupportedDiskInterface(disk.kind, disk.interface)
            }
        }
    }

    /// This method builds the configuration of the virtual machine in three steps: the template is checked
    /// first, so that a description this backend cannot honour leaves nothing behind on disk; then the folder
    /// of the VM and its disks are located (and created, if missing); finally the configuration scheme is put together.
    ///
    /// Only macOS guests need a restore image, other platforms skip directly to `createConfiguration(using: nil, disks:)`.
    /// After that call terminates, the method validates the configuration scheme and returns it to its caller,
    /// together with the resources that have to outlive it.
    func createConfiguration() async throws -> (VZVirtualMachineConfiguration, AppleMachineResources) {

        try Self.validate(template, options: options)

        try FileManager.default.createDirectory(
            at: vmSupportDirectory,
            withIntermediateDirectories: true
        )

        let disks = try DiskImageStore(directory: vmSupportDirectory).provision(
            DiskImage.bootSequence(of: template.storage)
        )

        var restoreImageAccess: SecurityScopedAccess? = nil

        switch options.platform {
        case .macOS(let version, let bookmark):

            var restoreImage: VZMacOSRestoreImage? = nil

            // An installed machine works without its restore image, so one that cannot be
            // located or read anymore is not an error by itself.
            if let bookmark {
                restoreImageAccess = try? SecurityScopedAccess(resolving: bookmark)
            }

            if  let url = restoreImageAccess?.url,
                let image = try? await VZMacOSRestoreImage.load(from: url) {
                
                let macOSImageVersion = AppleMachineOptions.Version(
                    image.operatingSystemVersion
                )
                
                guard macOSImageVersion.major == version.major else {
                    throw VZKitError.wrongMacImageVersion(version, macOSImageVersion)
                }
                
                restoreImage = image
            }
            
            try await createConfiguration(using: restoreImage, disks: disks)
            
        case .linux: try await createConfiguration(using: nil, disks: disks)
        }
        
        try configuration.validate()

        return (configuration, .init(
            mediaAccess: disks.compactMap(\.access),
            restoreImage: restoreImageAccess
        ))
    }
    
    /// The explicit initializer of the struct.
    ///
    /// - Parameters:
    ///   - template: The data transfer object containing all the info about the virtual machine.
    ///   - options: The settings only this backend understands.
    init(template: Template, options: AppleMachineOptions) async {
        self.template = template
        self.options = options
        
        self.configuration = VZVirtualMachineConfiguration()
        
        self.vmSupportDirectory = await VirtualizationKit.supportDirectory.appendingPathComponent(
            template.id.uuidString
        )
    }
}

/// What an Apple virtual machine has to keep alive next to its configuration.
///
/// The configuration refers to files by location only. Inside the App Sandbox, the ones living outside
/// of the application container stay reachable just as long as these guards exist.
struct AppleMachineResources: Sendable {

    /// The guards of the external disk images attached to the machine.
    let mediaAccess: [SecurityScopedAccess]

    /// The guard of the macOS restore image, when the template refers to one that could be located.
    let restoreImage: SecurityScopedAccess?
}
