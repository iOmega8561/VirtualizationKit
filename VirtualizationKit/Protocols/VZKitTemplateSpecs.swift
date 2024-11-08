//
//  VZKitTemplateSpecs.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 12/10/24.
//

import Virtualization

/// The `VZKitTemplateSpecs` protocol defines a common structure for the information that will be stored inside a template
/// regarding the hardware characteristics of the virtual machine that will be created.
public protocol VZKitTemplateSpecs: Codable, Hashable, Sendable {
        
    /// The amount of CPU cores that will be available to the VM
    var cpuCount: Int { get }
    
    /// The amount of RAM that will be available to the VM
    var ramSizeMB: Int { get }
    
    /// The amount of disk space that will be available to the VM
    var diskSizeGB: Int { get }
    
    /// A boolean value that dictates if the VM will have access to network
    var networkTopology: NetworkTopology { get }
    
    /// A boolean value that dictates if the VM will have access to a shared directory
    ///
    /// - Important: The shared directory will always be located at {VirtualizationKit.bundlePath}/{UUID}/{VM-NAME}
    var hasDirectoryShare: Bool { get }
    
    /// A boolean value that dictates if the VM will have access to microphone
    ///
    /// - Important: The root application needs NSMicrophoneUsage key in its Info settings.
    /// Without permission the machine will fail to configure.
    var hasInputAudio: Bool { get }
    
    /// A boolean value that dictates if the VM will have access to speakers
    var hasOutputAudio: Bool { get }
}
