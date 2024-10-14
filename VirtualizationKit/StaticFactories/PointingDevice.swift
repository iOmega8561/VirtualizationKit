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
//  PointingDevice.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 18/05/24.
//

import Virtualization

/// This typealias allows for cleaner-looking code
typealias PointingDevice = VZPointingDeviceConfiguration

/// Protocol conformation of `VZPointingDeviceConfiguration` to `VZKitDeviceAttachment`
///
/// @brief
///    The `VirtHandlerMachineDevice` protocol allows for a simpler implementation of the static factory method pattern.
///    This extension contains the necessary stubs to achieve conformation.
extension PointingDevice: VZKitDeviceAttachment {
   
    /// Much simpler than the other factory methods, this one just returns the appropriate pointing
    /// device configuration according to the OS of choice.
    ///
    /// - Parameters:
    ///   - type: The guest operating system.
    static func createDevice(_ type: OperatingSystem) -> PointingDevice {
        
        switch type {
        case .macos(let major, _):
            
            guard major > 12  else { fallthrough}
            
            return VZMacTrackpadConfiguration()
            
        case .linux:
            
            return VZUSBScreenCoordinatePointingDeviceConfiguration()
        }
    }
}
