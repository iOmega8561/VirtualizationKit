//
//  VZKitMachineInstaller.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 16/05/24.
//

import Combine
import Virtualization

/// VZKitMachineInstaller protocol
///
/// @brief
///    This protocol defines how a Virtual Machine installer should be implemented in this application.
///    It is actually very generic, as it doesn't even require any way to present the information to the end user
public protocol VZKitMachineInstaller: Sendable {
    
    var restoreImage: URL { get }
    
    var machine: VZVirtualMachine { get }
    
    @VZKitGlobalActor func startInstallation() async throws
}
