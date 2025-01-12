//
//  VZPointingDeviceConfiguration.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 18/05/24.
//

import Virtualization

extension VZPointingDeviceConfiguration: VZKitSpecializedConstructible {
   
    /// Much simpler than the other factory methods, this one just returns the appropriate pointing
    /// device configuration according to the OS of choice.
    ///
    /// - Parameters:
    ///   - type: The guest operating system.
    static func create(type: OperatingSystem) -> Constructible {
        
        switch type {
        case .macos(let version):
            
            guard version.major > 12  else { fallthrough }
            
            return VZMacTrackpadConfiguration()
            
        case .linux:
            
            return VZUSBScreenCoordinatePointingDeviceConfiguration()
        }
    }
}
