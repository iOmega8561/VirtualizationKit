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
//  VZKitMachineConfigurator.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 14/05/24.
//

import Virtualization

/// VZKitMachineConfigurator protocol
///
/// @brief
///    This protocol defines how a Virtual Machine configurator should be implemented in this application
public protocol VZKitMachineConfigurator: Sendable {
    
    associatedtype TemplateType: VZKitTemplate
    
    /// A copy of the DTO to have all the necessary info about the VM template
    var template: TemplateType { get }
    
    /// Reference to the native `Virtualization` framework configuration object
    var configuration: VZVirtualMachineConfiguration { get }
    
    /// This method should have responsability to build the `VZVirtualMachineConfiguration` object and return that to the caller.
    func createConfiguration() async throws -> VZVirtualMachineConfiguration
}
