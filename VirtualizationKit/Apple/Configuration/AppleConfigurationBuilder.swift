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
    
    /// Reference to the native `Virtualization` framework configuration object
    let configuration: VZVirtualMachineConfiguration
    
    /// Stored property to get the location of the VM's storage folder inside the application bundle
    private let vmSupportDirectory: URL
    
    /// This method is responsible of building the full fledged virtual machine configuration scheme.
    /// To do that it makes a distinction between the different guest operating systems, since they need completely different
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
        
        switch template.operatingSystem {
        case .macos:
            
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
            
        case .windows:
            
            // Rejected by the public entry point already; kept for exhaustiveness.
            throw VZKitError.appleUnsupportedGuest(template.operatingSystem.displayName)
        }
      
        for disk in disks {
            configuration.storageDevices.append(try VZStorageDeviceConfiguration.create(for: disk))
        }
        
        configuration.consoleDevices.append(.create(type: template.operatingSystem))
        configuration.graphicsDevices.append(.create(type: (template.operatingSystem, template.display)))
        configuration.keyboards.append(.create(type: template.operatingSystem))
        configuration.pointingDevices.append(.create(type: template.operatingSystem))
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
                    type: template.operatingSystem
                )
            )
        }
        
        if #available(macOS 15.0, *), template.optionalCapabilities.contains(.xhciUSBHotSwap) {
            configuration.usbControllers.append(VZXHCIControllerConfiguration())
        }
    }
    
    /// Checks the disks of the template against what this backend can attach, without touching the
    /// file system.
    ///
    /// On top of the rules every backend shares, Virtualization.framework only offers NVMe
    /// controllers to Linux guests.
    private func validateStorage() throws {

        try DiskImage.validate(template.storage)

        for disk in template.storage {

            switch disk.format {
            case .raw: break
            }

            switch (disk.interface, template.operatingSystem) {
            case (.virtio, _), (.usb, _), (.nvme, .linux): break
            case (.nvme, .macos), (.nvme, .windows):
                throw VZKitError.unsupportedDiskInterface(disk.kind, disk.interface)
            }
        }
    }

    /// This method builds the configuration of the virtual machine in three steps: the template is checked
    /// first, so that a description this backend cannot honour leaves nothing behind on disk; then the folder
    /// of the VM and its disks are located (and created, if missing); finally the configuration scheme is put together.
    ///
    /// Only macOS guests need a restore image, other OSes skip directly to `createConfiguration(using: nil, disks:)`.
    /// After that call terminates, the method validates the configuration scheme and returns it to its caller,
    /// together with the resources that have to outlive it.
    func createConfiguration() async throws -> (VZVirtualMachineConfiguration, AppleMachineResources) {

        try validateStorage()

        try FileManager.default.createDirectory(
            at: vmSupportDirectory,
            withIntermediateDirectories: true
        )

        let disks = try DiskImageStore(directory: vmSupportDirectory).provision(
            DiskImage.bootSequence(of: template.storage)
        )

        var restoreImageAccess: SecurityScopedAccess? = nil
        
        switch template.operatingSystem {
        case .macos(let version, let bookmark):
            
            var restoreImage: VZMacOSRestoreImage? = nil
            
            // An installed machine works without its restore image, so one that cannot be
            // located or read anymore is not an error by itself.
            if let bookmark {
                restoreImageAccess = try? SecurityScopedAccess(resolving: bookmark)
            }

            if  let url = restoreImageAccess?.url,
                let image = try? await VZMacOSRestoreImage.load(from: url) {
                
                let macOSImageVersion = OperatingSystem.Version(
                    image.operatingSystemVersion
                )
                
                guard macOSImageVersion.major == version.major else {
                    throw VZKitError.wrongMacImageVersion(version, macOSImageVersion)
                }
                
                restoreImage = image
            }
            
            try await createConfiguration(using: restoreImage, disks: disks)
            
        case .linux: try await createConfiguration(using: nil, disks: disks)
            
        case .windows:
            
            // Virtualization.framework has no support for Windows guests.
            throw VZKitError.appleUnsupportedGuest(template.operatingSystem.displayName)
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
    init(template: Template) async {
        self.template = template
        
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
