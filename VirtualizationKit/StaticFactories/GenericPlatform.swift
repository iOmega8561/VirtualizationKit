//
//  GenericPlatform.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 07/10/24.
//

import Virtualization


/// This typealias allows for cleaner-looking code
typealias GenericPlatform = VZGenericPlatformConfiguration

extension GenericPlatform {
    
    /// This method checks if an already existing machine identifier file can be found on the host FS,
    /// and eventually returns that instance, otherwise a new file is created.
    ///
    /// - Parameters:
    ///   - url: Location of the machine identifier storage on the host file system.
    private static func generateMachineId(_ url: URL) throws -> VZGenericMachineIdentifier {
        
        guard FileManager.default.fileExists(
            atPath: url.path(percentEncoded: false)
            
        ) else {
            let machineId = VZGenericMachineIdentifier()
            
            try machineId.dataRepresentation.write(to: url)
            return machineId
        }
        
        guard let machineIdData = try? Data(contentsOf: url) else {
            throw VZKitError.machineIdRetrieve
        }
        
        guard let machineId = VZGenericMachineIdentifier(dataRepresentation: machineIdData) else {
            throw VZKitError.machineId
        }
        
        return machineId
    }
    
    /// This method can create a generic virtual machine platform configuration.
    /// It also takes care of calling the appropriate method to generate a machine identifier, then returns the full object, ready to use.
    ///
    /// - Parameters:
    ///   - url: Location on disk of the Virtual Machine storage directory.
    static func createDevice(_ url: URL) throws -> GenericPlatform {
        let platform = VZGenericPlatformConfiguration()
        platform.machineIdentifier = try generateMachineId(url)
        
        return platform
    }
}
