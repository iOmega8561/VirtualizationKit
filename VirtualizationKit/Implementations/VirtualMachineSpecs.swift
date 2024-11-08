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
//  VirtualMachineSpecs.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 25/04/24.
//

import Foundation

import Virtualization

/// The hardware specifications struct of our Virtual Machine
///
/// @brief
///    This struct defines the hardware caracteristics that will be
///    chosen by the user at creation time. This will be included in our VM Template configuration
public struct VirtualMachineSpecs: VZKitTemplateSpecs {
    
    /// The amount of CPU cores that will be available to the VM
    public var cpuCount: Int
    
    /// The amount of RAM that will be available to the VM
    public var ramSizeMB: Int
    
    /// The amount of disk space that will be available to the VM
    public var diskSizeGB: Int
    
    /// A boolean value that dictates if the VM will have access to network
    public var networkTopology: NetworkTopology

    /// A boolean value that dictates if the VM will have access to a shared directory
    public var hasDirectoryShare: Bool
    
    /// A boolean value that dictates if the VM will have access to microphone
    public var hasInputAudio: Bool
    
    /// A boolean value that dictates if the VM will have access to speakers
    public var hasOutputAudio: Bool
    
    public init(
        cpuCount: Int,
        ramSizeMB: Int,
        diskSizeGB: Int,
        networkTopology: NetworkTopology,
        hasDirectoryShare: Bool,
        hasInputAudio: Bool,
        hasOutputAudio: Bool
    ) {
        self.cpuCount = cpuCount
        self.ramSizeMB = ramSizeMB
        self.diskSizeGB = diskSizeGB
        self.networkTopology = networkTopology
        self.hasDirectoryShare = hasDirectoryShare
        self.hasInputAudio = hasInputAudio
        self.hasOutputAudio = hasOutputAudio
    }
}
