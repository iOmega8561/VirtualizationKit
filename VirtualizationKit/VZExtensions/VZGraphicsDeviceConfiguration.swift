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
//  VZGraphicsDeviceConfiguration.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 17/05/24.
//

import Virtualization

extension VZGraphicsDeviceConfiguration: VZKitSpecializedConstructible {
    
    /// This factory method can create a graphics device configuration for the guest machine.
    /// Configuration will be different according to the OS of choice, so the method takes the latter as input parameter
    /// and returns the appropriate attachment.
    ///
    /// - Parameters:
    ///   - type: The guest operating system.
    static func create(type: VZKitOperatingSystem) -> Constructible {

        switch type {
        case .macos:
            
            let dev = VZMacGraphicsDeviceConfiguration()
            
            dev.displays.append(
                VZMacGraphicsDisplayConfiguration(
                    widthInPixels: 1920,
                    heightInPixels: 1200,
                    pixelsPerInch: 80
                )
            )
            
            return dev
        default:
            
            let dev = VZVirtioGraphicsDeviceConfiguration()
            
            dev.scanouts.append(
                VZVirtioGraphicsScanoutConfiguration(
                    widthInPixels: 1280,
                    heightInPixels: 720
                )
            )
            
            return dev
        }
    }
}
