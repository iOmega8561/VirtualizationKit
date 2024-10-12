//
//  VirtualMachineConfigurator.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 17/05/24.
//

@preconcurrency import Virtualization

/// `VirtualMachineConfigurator` data structure
///
/// @brief
///    The choice to make it a struct instead of a class derives from the fact that it is not necessary
///    to keep track of the identity of the instanciated object. This struct also conforms to `Sendable`,
///    as required by `VZKitMachineConfigurator`.
///
///    - Important: `VZVirtualMachineConfiguration` IS NOT sendable.
///      We import the `Virtualization` framework using `@preconcurrency`.
public struct VirtualMachineConfigurator<TemplateType: VZKitTemplate>: VZKitMachineConfigurator {
    
    /// A copy of the DTO to have all the necessary info about the VM template
    public let template: TemplateType
    
    /// Reference to the native `Virtualization` framework configuration object
    public let configuration: VZVirtualMachineConfiguration
    
    /// Computed property to get the location of the VM's storage folder inside the application bundle
    private var bundlePath: String {
        return FileManager.default.homeDirectoryForCurrentUser.path() +
               "/VirtualizationKit.bundle/"
               + template.id.uuidString
    }

    /// This method is responsible of building the full fledged virtual machine configuration scheme.
    /// To do that it makes a distinction between the different guest operating systems, since they need completely different
    /// configuration schemes. Its workings are helped by the several static factory methods implemented for every virtual device.
    /// It also creates the VM folder if the latter doesn't exist already.
    ///
    /// - Parameters:
    ///   - image: The macOS restore image object, if needed.
    private func createConfiguration(_ image: VZMacOSRestoreImage?) throws {
        
        if !FileManager.default.fileExists(atPath: bundlePath) {
            try FileManager.default.createDirectory(
                atPath: bundlePath,
                withIntermediateDirectories: true
            )
        }
        
        switch template.os.type {
        case .macos:
            
            configuration.platform = try MacintoshPlatform.createDevice(image!, bundlePath)
            
            configuration.bootLoader = try BootLoader.createDevice()
            
        case .linux:
            
            configuration.platform = try GenericPlatform.createDevice(bundlePath)
            
            configuration.bootLoader = try BootLoader.createDevice(bundlePath + "/NVRAM")
            
            configuration.directorySharingDevices.append(
                try RosettaDevice.createDevice()
            )
            
            if let url = template.os.installer {
                configuration.storageDevices.append(
                    try USBMassStorageDevice.createDevice(url, .readOnly)
                )
            }
        }
        
        configuration.storageDevices.append(
            try BlockDevice.createDevice(
                bundlePath + "/Disk.img",
                .readWrite(size: template.specs.diskSizeGB)
            )
        )
        
        configuration.consoleDevices.append(
            ConsoleDevice.createDevice()
        )
        
        configuration.graphicsDevices.append(
            GraphicsDevice.createDevice(template.os.type)
        )
        
        configuration.keyboards.append(
            KeyboardDevice.createDevice(template.os.type)
        )
        
        configuration.pointingDevices.append(
            PointingDevice.createDevice(template.os.type)
        )
        
        configuration.memoryBalloonDevices.append(
            VZVirtioTraditionalMemoryBalloonDeviceConfiguration()
        )
        
        configuration.entropyDevices.append(
            VZVirtioEntropyDeviceConfiguration()
        )
        
        if template.specs.hasNetwork {
            configuration.networkDevices.append(
                NetworkDevice.createDevice(.nat)
            )
        }
        
        if template.specs.hasOutputAudio {
            configuration.audioDevices.append(
                SoundDevice.createDevice(.output)
            )
        }
        
        if template.specs.hasInputAudio {
            configuration.audioDevices.append(
                SoundDevice.createDevice(.input)
            )
        }
        
        if template.specs.hasDirectoryShare {
            configuration.directorySharingDevices.append(
                try FileSystemDevice.createDevice(
                    bundlePath + "/SharedDirectory",
                    template.os.type
                )
            )
        }
        
        configuration.cpuCount = template.specs.cpuCount
        
        configuration.memorySize = UInt64(template.specs.ramSizeMB * 1024 * 1024)
    }
    
    /// This method prepares the macOS restore image for the configuration process.
    /// Only macOS guests need to go through this part, other OSes will skip directly to `createConfiguration(nil)`.
    /// After the synchronous call terminates, the methods validates the configuration scheme and returns it to its caller.
    public func createConfiguration() async throws -> VZVirtualMachineConfiguration {
        
        switch template.os.type {
        case .macos:
            
            guard let url = template.os.installer else {
                throw VZKitError.missingMacImage
            }
            
            let image: VZMacOSRestoreImage = try await withCheckedThrowingContinuation({ continuation in
                VZMacOSRestoreImage.load(from: url) { result in
                    switch result {
                    case let .failure(error):
                        continuation.resume(throwing: error)
                    case let .success(systemImage):
                        continuation.resume(returning: systemImage)
                    }
                }
            })
            
            try createConfiguration(image)
            
        default:
            
            try createConfiguration(nil)
        }
        
        try configuration.validate()
        return configuration
    }
    
    /// The explicit initializer of the struct.
     
    /// - Parameters:
    ///   - template: The data transfer object containing all the info about the virtual machine.
    init(template: TemplateType) {
        self.template = template
        self.configuration = VZVirtualMachineConfiguration()
    }
}
