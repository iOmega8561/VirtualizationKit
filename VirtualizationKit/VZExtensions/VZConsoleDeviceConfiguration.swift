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
//  VZConsoleDeviceConfiguration.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 17/05/24.
//

import Virtualization

extension VZConsoleDeviceConfiguration: VZKitSpecializedConstructible {
    
    typealias Constructible = VZVirtioConsoleDeviceConfiguration
    
    /// Static factory method for `VZVirtioConsoleDeviceConfiguration`.
    /// Spice console configuration is standard across the different vm types, the only difference is that currently
    /// Clipboard sharing is not supported for macOS guests, so we explicitly disable it in that case.
    static func create(type: OperatingSystem) -> Constructible {
        let dev = Constructible()
        let portAttachment = VZSpiceAgentPortAttachment()
        
        switch type {
        case .macos:
            portAttachment.sharesClipboard = false
            
        default:
            portAttachment.sharesClipboard = true
        }
                
        let spiceAgentPort = VZVirtioConsolePortConfiguration()
        spiceAgentPort.name = VZSpiceAgentPortAttachment.spiceAgentPortName
        spiceAgentPort.attachment = portAttachment
        
        dev.ports[0] = spiceAgentPort
        
        return dev
    }
}
