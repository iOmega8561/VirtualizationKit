//
//  NetworkDevice.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 17/05/24.
//

import Virtualization

/// This typealias allows for cleaner-looking code
typealias NetworkDevice = VZVirtioNetworkDeviceConfiguration

/// Protocol conformation of `VZVirtioNetworkDeviceConfiguration` to `VZKitDeviceAttachment`
///
/// @brief
///    The `VZKitDeviceAttachment` protocol allows for a simpler implementation of the static factory method pattern.
///    This extension contains the necessary stubs to achieve conformation and defines an appropriare `CaseIterable`
///    to be used as argument, when calling the factory method.
extension NetworkDevice: VZKitDeviceAttachment {
    
    /// NetworkType `CaseIterable`
    ///
    /// @brief
    ///    When calling the factory method from the outside, this `CaseIterable` becomes very useful
    ///    to provide concise information about the network capabilities of the guest machine.
    enum NetworkType: CaseIterable {
        case nat
        case bridge
    }
    
    /// This static factory method returns the appropriate network attachment.
    /// Network configurations are handled the same way across different OSes, but themselves may need
    /// to be created differently in order to account for, eventually, different virtual network topologies.
    ///
    /// - Parameters:
    ///   - type: The network configuration of choice
    static func createDevice(_ type: NetworkType) -> NetworkDevice {
        let dev = NetworkDevice()
        
        switch type {
        default:
            dev.attachment = VZNATNetworkDeviceAttachment()
        }
        
        // TBD Bridge network (requires entitlements)
        
        return dev
    }
}
