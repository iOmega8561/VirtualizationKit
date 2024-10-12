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
