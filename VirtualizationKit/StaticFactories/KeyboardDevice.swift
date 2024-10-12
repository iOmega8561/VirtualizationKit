//
//  KeyboardDevice.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 18/05/24.
//

import Virtualization


/// This typealias allows for cleaner-looking code
typealias KeyboardDevice = VZKeyboardConfiguration

/// Protocol conformation of `VZKeyboardConfiguration` to `VZKitDeviceAttachment`
///
/// @brief
///    The `VZKitDeviceAttachment` protocol allows for a simpler implementation of the static factory method pattern.
///    This extension contains the necessary stubs to achieve conformation.
extension KeyboardDevice: VZKitDeviceAttachment {
   
    /// Much simpler than the other factory methods, this one just returns the appropriate keyboard
    /// configuration according to the OS of choice.
    ///
    /// - Parameters:
    ///   - type: The guest operating system.
    static func createDevice(_ type: OperatingSystem) -> KeyboardDevice {
        
        switch type {
        case .linux:
            return VZUSBKeyboardConfiguration()
        case .macos:
            return VZMacKeyboardConfiguration()
        }
    }
}
