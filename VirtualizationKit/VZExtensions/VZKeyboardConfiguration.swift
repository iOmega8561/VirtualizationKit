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
//  VZKeyboardConfiguration.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 18/05/24.
//

import Virtualization

extension VZKeyboardConfiguration: VZKitSpecializedConstructible {
    
    /// Much simpler than the other factory methods, this one just returns the appropriate keyboard
    /// configuration according to the OS of choice.
    ///
    /// - Parameters:
    ///   - type: The guest operating system.
    static func create(type: OperatingSystem) -> Constructible {
        
        switch type {
        case .macos(let version):
            
            guard version.major > 12  else { fallthrough }
            
            return VZMacKeyboardConfiguration()
            
        case .linux:
            
            return VZUSBKeyboardConfiguration()
        }
    }
}
