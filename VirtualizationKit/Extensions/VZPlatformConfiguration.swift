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
//  VZPlatformConfiguration.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 07/10/24.
//

import Virtualization

extension VZPlatformConfiguration: VZKitPersistentConstructible {
    
    enum PlatformType {
        case generic(nestedVirtualization: Bool = false)
        case macintosh(restoreImage: VZMacOSRestoreImage)
    }
    
    // MARK: - Machine Identifier with Generics (Good for .generic and .macintosh)
    
    /// This method checks if an already existing machine identifier file can be found on the host FS,
    /// and eventually returns that instance, otherwise a new file is created.
    ///
    /// - Parameters:
    ///   - url: Location of the machine identifier storage on the host file system.
    private static func createMachineIdentifier<Identifier: MachineIdentifier>(at url: URL) throws -> Identifier {
        
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
            let machineId = Identifier()
            try machineId.dataRepresentation.write(to: url)
            return machineId
        }
        
        guard let machineIdData = try? Data(contentsOf: url) else {
            throw VZKitError.machineIdMissing
        }
        
        guard let machineId = Identifier(dataRepresentation: machineIdData) else {
            throw VZKitError.machineIdCorrupt
        }
        
        return machineId
    }
    
    // MARK: - Macintosh Platform
    
    /// This method checks if an already existing auxiliary storage can be found,
    /// and eventually returns that instance, otherwise a new file is created.
    ///
    /// - Parameters:
    ///   - url: Location of the auxiliary storage on the host file system.
    ///   - hwModel: The macOS restore image most featureful supported hardware model.
    private static func createAuxStorage(at url: URL, hwModel: VZMacHardwareModel) throws -> VZMacAuxiliaryStorage {
        
        guard !FileManager.default.fileExists(
            atPath: url.path(percentEncoded: false)
            
        )  else { return VZMacAuxiliaryStorage(url: url) }
        
        let auxiliaryStorage = try VZMacAuxiliaryStorage(
            creatingStorageAt: url,
            hardwareModel: hwModel
        )
        
        return auxiliaryStorage
    }
    
    /// This method can create a generic virtual machine platform configuration.
    /// It also takes care of calling the appropriate method to generate a machine identifier, then returns the full object, ready to use.
    ///
    /// - Parameters:
    ///   - url: Location on disk of the Virtual Machine storage directory.
    ///   - nestedVZ: Whether the platform should enable nested virtualization
    static func create(at url: URL, type: PlatformType) throws -> Constructible {
        
        let platform: VZPlatformConfiguration
        
        switch type {
        case .generic(let nestedVZ):
            
            let genericPlatform = VZGenericPlatformConfiguration()
            
            genericPlatform.machineIdentifier = try createMachineIdentifier(
                at: url.appendingPathComponent("MachineIdentifier")
            )
            
            guard nestedVZ else { platform = genericPlatform; break }
            
            guard #available(macOS 15.0, *),
                  VZGenericPlatformConfiguration.isNestedVirtualizationSupported else {
                throw VZKitError.hostFeatureUnsupported("Nested Virtualization")
            }
            
            genericPlatform.isNestedVirtualizationEnabled = nestedVZ
            platform = genericPlatform
            
        case .macintosh(let restoreImage):
            
            guard let requirements = restoreImage.mostFeaturefulSupportedConfiguration else {
                throw VZKitError.macUnsupportedImage
            }
            
            guard requirements.hardwareModel.isSupported else {
                throw VZKitError.macUnsupportedHost
            }
            
            let macintoshPlatform = VZMacPlatformConfiguration()
            
            macintoshPlatform.hardwareModel = requirements.hardwareModel
            
            macintoshPlatform.machineIdentifier = try createMachineIdentifier(
                at: url.appendingPathComponent("MachineIdentifier")
            )
            
            macintoshPlatform.auxiliaryStorage = try createAuxStorage(
                at: url.appendingPathComponent("AuxiliaryStorage"),
                hwModel: macintoshPlatform.hardwareModel
            )
            
            platform = macintoshPlatform
            
        }
        
        return platform
    }
}
