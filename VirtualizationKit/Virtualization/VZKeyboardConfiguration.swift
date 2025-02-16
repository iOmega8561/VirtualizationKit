//
//  VZKeyboardConfiguration.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 18/05/24.
//

import Virtualization

extension VZKeyboardConfiguration: SpecializedConstructible {
    
    /// Much simpler than the other factory methods, this one just returns the appropriate keyboard
    /// configuration according to the OS of choice.
    ///
    /// - Parameters:
    ///   - type: The guest operating system.
    static func create(type: OperatingSystem) -> Product {
        
        switch type {
        case .macos(let version):
            
            guard version.major > 12  else { fallthrough }
            
            return VZMacKeyboardConfiguration()
            
        case .linux:
            
            return VZUSBKeyboardConfiguration()
        }
    }
}
