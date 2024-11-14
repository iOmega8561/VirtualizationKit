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
    ///   - url: Location of the machine identifier storage on the host file system.
    private static func generateMacMachineId(_ url: URL) throws -> VZMacMachineIdentifier {
        
        guard FileManager.default.fileExists(
            atPath: url.path(percentEncoded: false)
            
        ) else {
            let machineId = VZMacMachineIdentifier()
            
            try machineId.dataRepresentation.write(to: url)
            return machineId
        }
        
        guard let machineIdData = try? Data(contentsOf: url) else {
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
    ///   - url: Location of the auxiliary storage on the host file system.
    private static func generateMacAuxiliaryStorage(
        _ hwModel: VZMacHardwareModel,
        _ url: URL
    ) throws -> VZMacAuxiliaryStorage {
        
        guard !FileManager.default.fileExists(
            atPath: url.path(percentEncoded: false)
            
        )  else { return VZMacAuxiliaryStorage(url: url) }
        
        let auxStore = try VZMacAuxiliaryStorage(
            creatingStorageAt: url,
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
    ///   - url: Location on disk of the Virtual Machine storage directory.
    static func createDevice(_ image: MacOSRestoreImage, _ url: URL) throws -> MacintoshPlatform {
        
        guard let requirements = image.mostFeaturefulSupportedConfiguration else {
            throw VZKitError.macUnsupportedImage
        }
        
        guard requirements.hardwareModel.isSupported else {
            throw VZKitError.macUnsupportedHost
        }
        
        let platform = VZMacPlatformConfiguration()
        
        platform.hardwareModel = requirements.hardwareModel
        
        platform.machineIdentifier = try generateMacMachineId(
            url.appendingPathComponent("MachineIdentifier")
        )
        
        platform.auxiliaryStorage = try generateMacAuxiliaryStorage(
            platform.hardwareModel,
            url.appendingPathComponent("AuxiliaryStorage")
        )
        
        return platform
    }
}
