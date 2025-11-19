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
//  VZConsoleDeviceConfiguration.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 17/05/24.
//

import Virtualization

extension VZConsoleDeviceConfiguration: SpecializedConstructible {
    
    typealias Product = VZVirtioConsoleDeviceConfiguration
    
    /// Static factory method for `VZVirtioConsoleDeviceConfiguration`.
    /// Spice console configuration is standard across the different vm types, the only difference is that currently
    /// Clipboard sharing is not supported for macOS guests, so we explicitly disable it in that case.
    static func create(type: OperatingSystem) -> Product {
        let dev = Product()
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
