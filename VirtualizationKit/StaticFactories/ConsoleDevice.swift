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
//  ConsoleDevice.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 17/05/24.
//

import Virtualization


/// This typealias allows for cleaner-looking code
typealias ConsoleDevice = VZVirtioConsoleDeviceConfiguration

extension ConsoleDevice {
    
    /// Static factory method for `VZVirtioConsoleDeviceConfiguration`.
    /// Spice console configuration is standard across the different vm types.
    static func createDevice() -> ConsoleDevice {
        let dev = ConsoleDevice()
        
        let spiceAgentPort = VZVirtioConsolePortConfiguration()
        spiceAgentPort.name = VZSpiceAgentPortAttachment.spiceAgentPortName
        spiceAgentPort.attachment = VZSpiceAgentPortAttachment()
        
        dev.ports[0] = spiceAgentPort
        
        return dev
    }
}
