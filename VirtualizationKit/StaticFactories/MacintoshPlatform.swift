//
//  MacintoshPlatform.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 07/10/24.
//

import Virtualization

/// This typealias allows for cleaner-looking code
typealias MacintoshPlatform = VZMacPlatformConfiguration

extension MacintoshPlatform {
    
    /// This method checks if an already existing machine identifier file can be found on the host FS,
    /// and eventually returns that instance, otherwise a new file is created.
    ///
    /// - Parameters:
    ///   - path: Location of the machine identifier storage on the host file system.
    private static func generateMacMachineId(_ path: String) throws -> VZMacMachineIdentifier {
        
        guard FileManager.default.fileExists(atPath: path) else {
            let machineId = VZMacMachineIdentifier()
            
            try machineId.dataRepresentation.write(to: URL(filePath: path))
            return machineId
        }
        
        guard let machineIdData = try? Data(contentsOf: URL(filePath: path)) else {
            throw VZKitError.machineIdRetrieve
        }
        
        guard let machineId = VZMacMachineIdentifier(dataRepresentation: machineIdData) else {
            throw VZKitError.machineId
        }
        
        return machineId
    }
    
    /// This method checks if an already existing auxiliary storage can be found,
    /// and eventually returns that instance, otherwise a new file is created.
    ///
    /// - Parameters:
    ///   - hwModel: The macOS restore image most featureful supported hardware model.
    ///   - path: Location of the auxiliary storage on the host file system.
    private static func generateMacAuxiliaryStorage(
        _ hwModel: VZMacHardwareModel,
        _ path: String
    ) throws -> VZMacAuxiliaryStorage {
        
        guard !FileManager.default.fileExists(atPath: path)  else {
            return VZMacAuxiliaryStorage(url: URL(filePath: path))
        }
        
        let auxStore = try VZMacAuxiliaryStorage(
            creatingStorageAt: URL(filePath: path),
            hardwareModel: hwModel
        )
        
        return auxStore
    }
    
    /// This method can create a macOS specifc platform configuration for the guest machine.
    /// By design it is possible that not every macOS restore image is compatible with the host machine, so the logic
    /// checks if the current host configuration is supported by the image, and throws an exception if it does not.
    /// In contrast with `VZGenericPlatformConfiguration`, this one also manages the EFI variable store, so we also need
    /// to create an `VZMacAuxiliaryStorage` and bind it to the platform, before returning the full object to the caller.
    ///
    /// - Parameters:
    ///   - image: The macOS guest restore image, as a ready to go MacOSRestoreImage object.
    ///   - path: Location on disk of the Virtual Machine storage directory.
    static func createDevice(_ image: MacOSRestoreImage, _ path: String) throws -> MacintoshPlatform {
        
        guard let requirements = image.mostFeaturefulSupportedConfiguration else {
            throw VZKitError.macUnsupportedImage
        }
        
        guard requirements.hardwareModel.isSupported else {
            throw VZKitError.macUnsupportedHost
        }
        
        let platform = VZMacPlatformConfiguration()
        
        platform.hardwareModel = requirements.hardwareModel
        
        platform.machineIdentifier = try generateMacMachineId(path + "/MachineIdentifier")
        
        platform.auxiliaryStorage = try generateMacAuxiliaryStorage(
            platform.hardwareModel,
            path + "/AuxiliaryStorage"
        )
        
        return platform
    }
}
