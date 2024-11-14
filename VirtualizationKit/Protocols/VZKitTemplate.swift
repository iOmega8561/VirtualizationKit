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
    
    /// Timestamp marking the creation or last modification date of the template.
    var timestamp: Date { get }
    
    /// Descriptive name of the template.
    var name: String { get }
    
    /// Array of URLs pointing to CD-ROM images or media to be used with the VM.
    var cdRomArray: [URL] { get }
    
    /// The operating system type and configuration associated with this template.
    var operatingSystem: OperatingSystem { get }
    
    /// Optional URL pointing to a system image from which the VM can be restored, if available.
    var restoreFromImage: URL? { get }
    
    /// The network topology setup for the VM, defining its network configuration.
    var networkTopology: NetworkTopology { get }
    
    /// The number of CPU cores to allocate to the VM.
    var cpuCoreCount: Int { get }
    
    /// The size of memory, in megabytes, to allocate to the VM.
    var memorySizeMegaBytes: Int { get }
    
    /// The size of disk storage, in gigabytes, to allocate to the VM.
    var diskSizeGigaBytes: Int { get }
    
    /// A Boolean value that indicates whether a shared directory is enabled between the host and VM.
    var enablesSharedDirectory: Bool { get }
    
    /// A Boolean value that indicates whether input audio support is enabled for the VM.
    var enablesInputAudio: Bool { get }
    
    /// A Boolean value that indicates whether output audio support is enabled for the VM.
    var enablesOutputAudio: Bool { get }
}
