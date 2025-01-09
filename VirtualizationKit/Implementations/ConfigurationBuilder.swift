//
//  Copyright (C) Giuseppe Rocco - All Rights Reserved
//  Unauthorized copying, modification or distribution of this source code,
//  via any medium is strictly prohibited and penally persecutable
//
//  This project and its source code are PROPRIETARY AND CONFIDENTIAL
//  Written by Giuseppe Rocco <giusepperocco38@gmail.com>, May 2024
//
//  -----------------------------------------------------------------------
//
//  ConfigurationBuilder.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 17/05/24.
//

@preconcurrency import Virtualization

/// `ConfigurationBuilder` data structure
///
/// @brief
///    The choice to make it a struct instead of a class derives from the fact that it is not necessary
///    to keep track of the identity of the instanciated object. This struct also conforms to `Sendable`,
///    as required by `VZKitMachineConfigurator`. This is the default implementation of the Builder pattern
///
///    - Important: `VZVirtualMachineConfiguration` IS NOT sendable.
///      We import the `Virtualization` framework using `@preconcurrency`.
struct ConfigurationBuilder<TemplateType: VZKitTemplate>: VZKitConfigurationBuilder {
    
    /// A copy of the DTO to have all the necessary info about the VM template
    let template: TemplateType
    
    /// Reference to the native `Virtualization` framework configuration object
    let configuration: VZVirtualMachineConfiguration
    
    /// Stored property to get the location of the VM's storage folder inside the application bundle
    private let vmSupportDirectory: URL
    
    /// Computed property that determines, based on current system version, if nestedVirtualization should be enabled
    /// - Note: If macOS is inferior to 15.0 this is always false, else it is `template.enablesNestedVirtualization`
    private var enablesNestedVirtualization: Bool {
        if #available(macOS 15.0, *) { template.enablesNestedVirtualization } else { false }
    }
    
    /// This method is responsible of building the full fledged virtual machine configuration scheme.
    /// To do that it makes a distinction between the different guest operating systems, since they need completely different
    /// configuration schemes. Its workings are helped by the several static factory methods implemented for every virtual device.
    /// It also creates the VM folder if the latter doesn't exist already.
    ///
    /// - Parameters:
    ///   - image: The macOS restore image object, if needed.
    private func createConfiguration(_ restoreImage: MacOSRestoreImage?) async throws {
        
        try FileManager.default.createDirectory(
            at: vmSupportDirectory,
            withIntermediateDirectories: true
        )
        
        switch template.operatingSystem {
        case .macos:
            
            configuration.platform = try .create(
                at: vmSupportDirectory,
                type: .macintosh(restoreImage: restoreImage!)
            )
            
            configuration.bootLoader = try .create()
            
        case .linux:
            
            configuration.platform = try .create(
                at: vmSupportDirectory,
                type: .generic(nestedVirtualization: enablesNestedVirtualization)
            )
            
            configuration.bootLoader = try .create(
                at: vmSupportDirectory.appendingPathComponent("NVRAM")
            )
            
            if template.enablesRosettaDirectoryShare {
                configuration.directorySharingDevices.append(try VZLinuxRosettaDirectoryShare.create())
            }
            
            if let url = template.removableDiskImage {
                configuration.storageDevices.append(
                    try VZUSBMassStorageDeviceConfiguration.create(at: url, type: .readOnly)
                )
            }
        }
      
        configuration.storageDevices.append(
            try VZVirtioBlockDeviceConfiguration.create(
                at: vmSupportDirectory.appendingPathComponent("Disk.img"),
                type: .readWrite(size: template.performancePreset.diskSize)
            )
        )
        
        configuration.consoleDevices.append(.create(type: template.operatingSystem))
        configuration.graphicsDevices.append(.create(type: template.operatingSystem))
        configuration.keyboards.append(.create(type: template.operatingSystem))
        configuration.pointingDevices.append(.create(type: template.operatingSystem))
        configuration.networkDevices.append(try .create(type: template.networkTopology))
        configuration.cpuCount = template.performancePreset.cpuCoreCount
        configuration.memorySize = template.performancePreset.memorySize
        configuration.memoryBalloonDevices.append(VZVirtioTraditionalMemoryBalloonDeviceConfiguration())
        configuration.entropyDevices.append(VZVirtioEntropyDeviceConfiguration())
        
        if template.enablesOutputAudio {
            configuration.audioDevices.append(try await .create(type: .output))
        }
        
        if template.enablesInputAudio {
            configuration.audioDevices.append(try await .create(type: .input))
        }
        
        if template.enablesSharedDirectory {
            configuration.directorySharingDevices.append(
                try .create(
                    at: vmSupportDirectory.appendingPathComponent(template.name),
                    type: template.operatingSystem
                )
            )
        }
        
        if #available(macOS 15.0, *) {
            configuration.usbControllers.append(VZXHCIControllerConfiguration())
        }
    }
    
    /// This method prepares the macOS restore image for the configuration process.
    /// Only macOS guests need to go through this part, other OSes will skip directly to `createConfiguration(nil)`.
    /// After the synchronous call terminates, the methods validates the configuration scheme and returns it to its caller.
    func createConfiguration() async throws -> VZVirtualMachineConfiguration {
        
        switch template.operatingSystem {
        case .macos(let version):
            
            guard let url = template.removableDiskImage else {
                throw VZKitError.missingMacImage
            }
            
            let image: MacOSRestoreImage = try await .load(from: url)
            
            guard image.osVersion == version else {
                throw VZKitError.wrongMacImageVersion(version, image.osVersion)
            }
            
            try await createConfiguration(image)
            
        default:
            
            try await createConfiguration(nil)
        }
        
        try configuration.validate(); return configuration
    }
    
    /// The explicit initializer of the struct.
    ///
    /// - Parameters:
    ///   - template: The data transfer object containing all the info about the virtual machine.
    init(template: TemplateType) async {
        self.template = template
        
        self.configuration = VZVirtualMachineConfiguration()
        
        self.vmSupportDirectory = await VirtualizationKit.supportDirectory.appendingPathComponent(
            template.id.uuidString
        )
    }
}
