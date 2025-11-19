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
//  VZBootLoader.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 07/10/24.
//

import Virtualization

extension VZBootLoader: GenericConstructible {
    
    /// This version of createDevice() provides a generic EFI bootloader configuration.
    /// The input argument is needed to create the appropriate EFI variable store on the host file system.
    ///
    /// - Parameters:
    ///   - url: Location on disk of the Virtual Machine storage directory.
    static func create(at url: URL) throws -> Product {
        let efiBootLoader = VZEFIBootLoader()
        
        if FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
            efiBootLoader.variableStore = VZEFIVariableStore(
                url: url
            )
            
        } else {
            efiBootLoader.variableStore = try VZEFIVariableStore(
                creatingVariableStoreAt: url
            )
        }
        
        return efiBootLoader
    }
    
    /// This version of createDevice() does not take any arguments because macOS guests do not need to
    /// bind an EFI variable store in their bootloader configuration. The variable store will be handled by the platform configuration.
    static func create() throws -> Product {
        
        return VZMacOSBootLoader()
    }
}
