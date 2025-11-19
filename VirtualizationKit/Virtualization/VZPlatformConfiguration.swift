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
//  VZPlatformConfiguration.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 07/10/24.
//

import Virtualization

extension VZPlatformConfiguration: PersistentConstructible {
    
    enum PlatformType {
        case generic(nestedVirtualization: Bool = false)
        case macintosh(restoreImage: VZMacOSRestoreImage?)
    }
    
    // MARK: - Macintosh Platform Specific
    
    /// This method checks if an already existing auxiliary storage can be found,
    /// and eventually returns that instance, otherwise a new file is created.
    ///
    /// - Parameters:
    ///   - url: Location of the auxiliary storage on the host file system.
    ///   - hwModel: The macOS restore image most featureful supported hardware model.
    private static func createAuxStorage(at url: URL, hwModel: VZMacHardwareModel) throws -> VZMacAuxiliaryStorage {
        
        guard !FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
            return VZMacAuxiliaryStorage(url: url)
        }
        
        let auxiliaryStorage = try VZMacAuxiliaryStorage(
            creatingStorageAt: url,
            hardwareModel: hwModel
        )
        
        return auxiliaryStorage
    }
    
    // MARK: - PersistentConstructible
    
    /// This method can create a generic virtual machine platform configuration.
    /// It also takes care of calling the appropriate method to generate a machine identifier, then returns the full object, ready to use.
    ///
    /// - Parameters:
    ///   - url: Location on disk of the Virtual Machine storage directory.
    ///   - type: The additional configuration and platform type to generate the correct object
    static func create(at url: URL, type: PlatformType) throws -> Product {
        
        let platform: VZPlatformConfiguration
        
        switch type {
        case .generic(let nestedVZ):
            
            let genericPlatform = VZGenericPlatformConfiguration()
            
            genericPlatform.machineIdentifier = try .create(
                at: url.appendingPathComponent("MachineIdentifier")
            )
            
            guard nestedVZ else { platform = genericPlatform; break }
            
            guard #available(macOS 15.0, *),
                  OptionalCapability.isNestedVirtualizationSupported else {
                throw VZKitError.unsupportedFeature(.nestedVirtualization)
            }
            
            genericPlatform.isNestedVirtualizationEnabled = nestedVZ
            platform = genericPlatform
            
        case .macintosh(let restoreImage):
            
            let macintoshPlatform = VZMacPlatformConfiguration()
            
            if let restoreImage {
                
                guard let requirements = restoreImage.mostFeaturefulSupportedConfiguration else {
                    throw VZKitError.macUnsupportedImage
                }
                
                guard requirements.hardwareModel.isSupported else {
                    throw VZKitError.macUnsupportedHost
                }
                
                try requirements.hardwareModel.dataRepresentation.write(
                    to: url.appendingPathComponent("HardwareModel")
                )
                
                macintoshPlatform.hardwareModel = requirements.hardwareModel
                
            } else {
                
                macintoshPlatform.hardwareModel = try .create(
                    dataAt: url.appendingPathComponent("HardwareModel")
                )
            }
            
            macintoshPlatform.machineIdentifier = try .create(
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
