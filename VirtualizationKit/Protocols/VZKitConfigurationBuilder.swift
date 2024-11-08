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
//  VZKitConfigurationBuilder.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 14/05/24.
//

import Virtualization

/// The `VZKitConfigurationBuilder` protocol defines the blueprint for implementing a builder that configures
/// virtual machines within the VirtualizationKit framework.
///
/// This protocol encapsulates the necessary data and steps required to build a `VZVirtualMachineConfiguration`
/// object, allowing for a structured approach to configuring virtual machine instances.
///
/// Conformance to `VZKitConfigurationBuilder` requires an implementation that can handle the specifics of
/// setting up a virtual machine's configuration, using data from a provided template.
public protocol VZKitConfigurationBuilder: Sendable {
    
    /// The type of template used to configure the virtual machine.
    ///
    /// This associated type represents a concrete template conforming to `VZKitTemplate`. The template
    /// contains all the necessary information required to configure the virtual machine, such as hardware
    /// specifications, storage, and network settings.
    associatedtype TemplateType: VZKitTemplate
    
    /// A copy of the template containing all the essential information about the virtual machine setup.
    ///
    /// This property holds an instance of `TemplateType`, which provides the details needed to
    /// construct a virtual machine configuration. The builder relies on this template to gather
    /// data specific to the desired virtual machine setup.
    var template: TemplateType { get }
    
    /// A reference to the `VZVirtualMachineConfiguration` object from the `Virtualization` framework.
    ///
    /// This configuration object represents the native configuration that will be passed to
    /// the `Virtualization` framework. It contains the low-level configuration data for the
    /// virtual machine, such as CPU and memory allocation, and will be built based on the
    /// properties defined in `template`.
    var configuration: VZVirtualMachineConfiguration { get }
    
    /// Builds and returns a complete `VZVirtualMachineConfiguration` object.
    ///
    /// This method is responsible for constructing a `VZVirtualMachineConfiguration` instance
    /// using the data available in `template`. Once the configuration is fully built, it returns
    /// it to the caller. If any errors occur during the build process, they are thrown to the caller.
    ///
    /// - Returns: A fully configured `VZVirtualMachineConfiguration` instance ready to be used for
    ///   creating or running a virtual machine.
    ///
    /// - Throws: An error if the configuration build process fails due to missing or invalid data.
    func createConfiguration() async throws -> VZVirtualMachineConfiguration
}
