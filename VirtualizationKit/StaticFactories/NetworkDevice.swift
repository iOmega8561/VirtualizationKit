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
        
    /// This static factory method returns the appropriate network attachment.
    /// Network configurations are handled the same way across different OSes, but themselves may need
    /// to be created differently in order to account for, eventually, different virtual network topologies.
    ///
    /// - Parameters:
    ///   - type: The network configuration of choice
    static func createDevice(_ type: NetworkTopology) throws -> NetworkDevice {
        let dev = NetworkDevice()
                
        switch type {
        case .bridged(let hostInterfaceID):
            
            let interface = VZBridgedNetworkInterface.networkInterfaces.first(
                where: { $0.identifier == hostInterfaceID }
            )
            
            guard let interface else {
                throw VZKitError.bridgeInterfaceNotAvailable(hostInterfaceID)
            }
            
            dev.attachment = VZBridgedNetworkDeviceAttachment(
                interface: interface
            )
            
        case .nat:
            dev.attachment = VZNATNetworkDeviceAttachment()
            
        default:
            return dev
        }
                
        return dev
    }
}
