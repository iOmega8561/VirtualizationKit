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

/// This enumeration is well suited represent the possible network configurations available for the virtual machines.
/// This implementation just follows very closely the public interface that is `VZKitNetworkTopology`
public enum NetworkTopology: VZKitNetworkTopology {
    
    /// This static constant represents a default value for system network interface indentifier
    /// The value has been set to "lo0", which is not a valid interface for Apple Virtualization.
    private static let defaultInterfaceID: String = "lo0"
    
    /// This is needed to be able to conform CaseIterable
    public static let allCases: [Self] = [
        .none,
        .nat,
        .bridged(Self.defaultInterfaceID),
    ]
    
    /// The VM should not have a network interface
    case none
    
    /// The VM should be connected to the host network by NAT
    case nat
    
    /// The VM should have a bridge interface
    case bridged(_ hostInterfaceID: String)
}
