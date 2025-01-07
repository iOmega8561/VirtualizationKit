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
    
    /// Computed property to get the location of the VM's storage folder inside the application bundle
    private let vmSupportDirectory: URL
    
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
            
            configuration.platform = try MacintoshPlatform.createDevice(
                restoreImage!,
                vmSupportDirectory
            )
            
            configuration.bootLoader = try BootLoader.createDevice()
            
        case .linux:
            
            configuration.platform = try GenericPlatform.createDevice(
                vmSupportDirectory.appendingPathComponent("MachineIdentifier"),
                { if #available(macOS 15.0, *) { template.enablesNestedVirtualization } else { false } }()
            )
            
            configuration.bootLoader = try BootLoader.createDevice(
                vmSupportDirectory.appendingPathComponent("NVRAM")
            )
            
            if template.enablesRosettaDirectoryShare {
                configuration.directorySharingDevices.append(
                    try RosettaDevice.createDevice()
                )
            }
            
            if let url = template.removableDiskImage {
                configuration.storageDevices.append(
                    try USBMassStorageDevice.createDevice(url, .readOnly)
                )
            }
        }
      
        configuration.storageDevices.append(
            try BlockDevice.createDevice(
                vmSupportDirectory.appendingPathComponent("Disk.img"),
                .readWrite(size: template.performancePreset.diskSize)
            )
        )
        
        configuration.consoleDevices.append(
            ConsoleDevice.createDevice(template.operatingSystem)
        )
        
        configuration.graphicsDevices.append(
            GraphicsDevice.createDevice(template.operatingSystem)
        )
        
        configuration.keyboards.append(
            KeyboardDevice.createDevice(template.operatingSystem)
        )
        
        configuration.pointingDevices.append(
            PointingDevice.createDevice(template.operatingSystem)
        )
        
        configuration.memoryBalloonDevices.append(
            VZVirtioTraditionalMemoryBalloonDeviceConfiguration()
        )
        
        configuration.entropyDevices.append(
            VZVirtioEntropyDeviceConfiguration()
        )
        
        configuration.networkDevices.append(
            try NetworkDevice.createDevice(template.networkTopology)
        )
        
        if template.enablesOutputAudio {
            configuration.audioDevices.append(
                try await SoundDevice.createDevice(.output)
            )
        }
        
        if template.enablesInputAudio {
            configuration.audioDevices.append(
                try await SoundDevice.createDevice(.input)
            )
        }
        
        if template.enablesSharedDirectory {
            configuration.directorySharingDevices.append(
                try FileSystemDevice.createDevice(
                    vmSupportDirectory.appendingPathComponent(template.name),
                    template.operatingSystem
                )
            )
        }
        
        if #available(macOS 15.0, *) {
            configuration.usbControllers.append(VZXHCIControllerConfiguration())
        }
        
        configuration.cpuCount = template.performancePreset.cpuCoreCount
        
        configuration.memorySize = template.performancePreset.memorySize
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
