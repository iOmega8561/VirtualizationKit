//
//  VZKitTemplateSpecs.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 12/10/24.
//

public protocol VZKitTemplateSpecs: Codable, Hashable, Sendable {
    
    /// The amount of CPU cores that will be available to the VM
    var cpuCount: Int { get }
    
    /// The amount of RAM that will be available to the VM
    var ramSizeMB: Int { get }
    
    /// The amount of disk space that will be available to the VM
    var diskSizeGB: Int { get }
    
    /// A boolean value that dictates if the VM will have access to network
    var hasNetwork: Bool { get }
    
    /// A boolean value that dictates if the VM will have access to a shared directory
    var hasDirectoryShare: Bool { get }
    
    /// A boolean value that dictates if the VM will have access to microphone
    var hasInputAudio: Bool { get }
    
    /// A boolean value that dictates if the VM will have access to speakers
    var hasOutputAudio: Bool { get }
}
