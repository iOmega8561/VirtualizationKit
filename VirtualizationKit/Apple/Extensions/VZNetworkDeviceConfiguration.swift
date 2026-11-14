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
//  VZNetworkDeviceConfiguration.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 17/05/24.
//

import Virtualization

extension VZNetworkDeviceConfiguration: SpecializedConstructible {
    
    typealias Product = VZVirtioNetworkDeviceConfiguration
    
    /// Sets up a `VZMACAddress` from a provided MAC address string.
    ///
    /// This function validates and converts a given string representation of a MAC address into a `VZMACAddress` object.
    /// If the string is not a valid MAC address format, it throws an error.
    ///
    /// - Parameters:
    ///   - address: A `String` representing the MAC address to be configured. The string must conform to the valid MAC address format.
    /// - Returns: A valid `VZMACAddress` object created from the given string.
    /// - Throws:
    ///   - `VZKitError.invalidMacAddress` if the provided string does not represent a valid MAC address.
    ///
    /// ## Implementation Details:
    /// - The function uses `VZMACAddress(string:)` to attempt to create a `VZMACAddress` object.
    /// - A guard statement ensures the input string is successfully converted; otherwise, an error is thrown.
    /// - The criteria for a valid MAC address string include proper formatting (e.g., "00:1A:2B:3C:4D:5E").
    static private func setupMacAddress(_ address: String) throws -> VZMACAddress {
        
        guard let vzMacAddress = VZMACAddress(string: address) else {
            throw VZKitError.invalidMacAddress(address)
        }
        
        return vzMacAddress
    }
    
    /// Sets up a `VZBridgedNetworkDeviceAttachment` using an optional network interface identifier.
    ///
    /// This function establishes a bridged network device attachment by selecting a network interface.
    /// If an identifier is provided, the function attempts to find a matching interface.
    /// If no identifier is provided, it selects the first available network interface.
    ///
    /// - Parameters:
    ///   - id: An optional `String` representing the identifier of the desired network interface. If `nil`, the function selects the first available interface.
    /// - Returns: A `VZBridgedNetworkDeviceAttachment` configured with the specified or default network interface.
    /// - Throws:
    ///   - `VZKitError.bridgeInterfaceNotAvailable` if no matching or default interface is available.
    ///
    /// ## Implementation Details:
    /// - The function retrieves the list of network interfaces using `VZBridgedNetworkInterface.networkInterfaces`.
    /// - If an `id` is provided, it searches for an interface with a matching `identifier`.
    /// - If no `id` is provided, it selects the first available network interface in the list.
    /// - A guard statement ensures that a valid network interface is found; otherwise, an error is thrown.
    ///
    /// ## Criteria for Selection:
    /// - A matching interface must have an identifier that exactly matches the provided `id`.
    /// - If `id` is `nil`, the first interface in the list is used as the default selection.
    /// - If no interfaces are available, the function throws an error.
    static private func setupBridged(_ id: String?) throws -> VZBridgedNetworkDeviceAttachment {
        
        let interface: VZBridgedNetworkInterface?
        
        if let id {
            interface = VZBridgedNetworkInterface.networkInterfaces.first(
                where: { $0.identifier == id }
            )
            
        } else { interface = VZBridgedNetworkInterface.networkInterfaces.first }
        
        guard let interface else {
            throw VZKitError.bridgeNicUnavailable(id)
        }
        
        return VZBridgedNetworkDeviceAttachment(interface: interface)
    }
    
    /// This static factory method returns the appropriate network attachment.
    /// Network configurations are handled the same way across different OSes, but themselves may need
    /// to be created differently in order to account for, eventually, different virtual network topologies.
    ///
    /// - Parameters:
    ///   - type: The network configuration of choice
    static func create(type: NetworkTopology) throws -> Product {
        let dev = Product()
                
        switch type {
        case .bridged(let hostInterfaceID, let macAddress):
            
            dev.attachment = try setupBridged(hostInterfaceID)
            
            dev.macAddress = try setupMacAddress(macAddress)
            
        case .nat(let macAddress):
            dev.attachment = VZNATNetworkDeviceAttachment()
            
            dev.macAddress = try setupMacAddress(macAddress)
            
        default:
            break
        }

        return dev
    }
}
