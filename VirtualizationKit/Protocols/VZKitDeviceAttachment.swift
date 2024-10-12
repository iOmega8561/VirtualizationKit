//
//  VZKitDeviceAttachment.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 17/05/24.
//

import Virtualization

/// VZKitDeviceAttachment protocol
///
/// @brief
///    This protocol defines how a Virtual Machine device should be implemented in this application.
///    The static method "createDevice" resembles a factory pattern.
protocol VZKitDeviceAttachment {
    
    associatedtype DeviceType: VZKitDeviceAttachment
    
    associatedtype InputType: CaseIterable
    
    /// This is the static, standard factory method for any `VZKitDeviceAttachment` conforming class.
    /// It should create and return the appropriate device attachment ready to be used, based on the input type.
    ///
    /// - Parameters:
    ///   - type: The network configuration of choice
    static func createDevice(_ type: InputType) -> DeviceType
}
