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
public protocol VZKitTemplate: Identifiable, Hashable, Sendable, Codable {
    
    /// Unique identifier for the template instance.
    var id: UUID { get }
    
    /// Descriptive name of the template.
    var name: String { get }
    
    /// The operating system type and configuration associated with this template.
    var operatingSystem: OperatingSystem { get }
    
    /// A URL pointing to the chosen CD-ROM image or media to be used with the VM, if available
    var removableDiskImage: URL? { get }
    
    /// A Boolean value that allows to understeand if the virtual machine needs to be processed through an Installer facility.
    var restoreFromDiskImage: Bool { get }
    
    /// The network topology setup for the VM, defining its network configuration.
    var networkTopology: NetworkTopology { get }
    
    /// The performance preset that better descrives the capabilities that the VM should have, hardware wise.
    var performancePreset: PerformancePreset { get }
    
    /// A Boolean value that indicates whether a shared directory is enabled between the host and VM.
    var enablesSharedDirectory: Bool { get }
    
    /// A Boolean value that indicates whether input audio support is enabled for the VM.
    var enablesInputAudio: Bool { get }
    
    /// A Boolean value that indicates whether output audio support is enabled for the VM.
    var enablesOutputAudio: Bool { get }
}
