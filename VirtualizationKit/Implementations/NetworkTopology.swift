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
//  NetworkTopology.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 08/11/24.
//

/// `NetworkTopology` is an enumeration that represents the possible network configurations
/// available for virtual machines. This enumeration closely follows the interface defined
/// by the `VZKitNetworkTopology` protocol, providing specific cases for each network topology option.
public enum NetworkTopology: VZKitNetworkTopology {
    
    /// The default value for the system network interface identifier.
    ///
    /// This is set to `"lo0"`, which is a loopback interface and not a valid network
    /// interface for Apple Virtualization. This value acts as a placeholder.
    private static let defaultInterfaceID: String = "lo0"
    
    /// A collection of all available network topology cases.
    ///
    /// This static array includes `.none`, `.nat`, and `.bridged` (using the `defaultInterfaceID`)
    /// to satisfy the `CaseIterable` conformance required by the protocol.
    public static let allCases: [Self] = [
        .none,
        .nat,
        .bridged(Self.defaultInterfaceID),
    ]
    
    /// No network interface for the virtual machine.
    ///
    /// When this case is selected, the virtual machine will not be assigned any network
    /// connectivity, effectively isolating it from both the host and external networks.
    case none
    
    /// A NAT (Network Address Translation) network interface for the virtual machine.
    ///
    /// This case provides the virtual machine with network access via the host’s IP address,
    /// while isolating it from the rest of the host's local network. This is typically used to
    /// allow external network access without exposing the virtual machine to other devices on the same network.
    case nat
    
    /// A bridged network interface for the virtual machine.
    ///
    /// - Parameter hostInterfaceID: The identifier of the host network interface to use for
    ///   bridging. This allows the virtual machine to appear as a separate device on the
    ///   local network, with its own IP address, making it directly accessible to other
    ///   devices on the same network.
    ///
    /// The bridged mode is useful for cases where the virtual machine needs to interact with
    /// other devices on the network as if it were a standalone device. The specified
    /// `hostInterfaceID` determines which host interface is used for this connection.
    case bridged(_ hostInterfaceID: String)
}
