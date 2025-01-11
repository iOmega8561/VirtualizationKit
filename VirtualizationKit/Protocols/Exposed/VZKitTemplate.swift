//
//  VZKitTemplate.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 12/10/24.
//

import Foundation

/// The `VZKitTemplate` protocol defines a common interface for VM templates in the framework.
///
/// @brief
///    The framework relies on VM Templates to define virtual machine configurations. A Template is a streamlined
///    and minimal stored configuration containing essential details for VM creation, omitting the full `Virtualization Framework`
///    data. Templates ensure a simple yet complete setup for defining VMs within the framework.
public protocol VZKitTemplate: Identifiable, VZKitTransferable {
    
    /// Unique identifier for the template instance.
    var id: UUID { get }
    
    /// Descriptive name of the template.
    var name: String { get }
    
    /// The operating system type and configuration associated with this template.
    var operatingSystem: OperatingSystem { get }
    
    /// A URL pointing to the chosen CD-ROM image or media to be used with the VM, if available
    var removableInstallMedia: URL? { get }
    
    /// The network topology setup for the VM, defining its network configuration.
    var networkTopology: NetworkTopology { get }
    
    /// The performance preset that better descrives the capabilities that the VM should have, hardware wise.
    var performancePreset: PerformancePreset { get }
    
    
    var featuresToEnable: [VZKitFeature] { get }
}
