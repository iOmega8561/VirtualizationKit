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
//  BootLoader.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 07/10/24.
//

import Virtualization


/// This typealias allows for cleaner-looking code
public typealias BootLoader = VZBootLoader

extension BootLoader {
    
    /// This version of createDevice() provides a generic EFI bootloader configuration.
    /// The input argument is needed to create the appropriate EFI variable store on the host file system.
    ///
    /// - Parameters:
    ///   - path: Location on disk of the Virtual Machine storage directory.
    public static func createDevice(_ path: String) throws -> BootLoader {
        let efiBootLoader = VZEFIBootLoader()
        
        if FileManager.default.fileExists(atPath: path) {
            efiBootLoader.variableStore = VZEFIVariableStore(
                url: URL(filePath: path)
            )
        } else {
            efiBootLoader.variableStore = try VZEFIVariableStore(
                creatingVariableStoreAt: URL(filePath: path)
            )
        }
        
        return efiBootLoader
    }
    
    /// This version of createDevice() does not take any arguments because macOS guests do not need to
    /// bind an EFI variable store in their bootloader configuration. The variable store will be handled by the platform configuration.
    public static func createDevice() throws -> BootLoader {
        
        return VZMacOSBootLoader()
    }
}
