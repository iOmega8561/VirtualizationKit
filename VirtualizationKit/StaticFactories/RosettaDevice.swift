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
//  RosettaDevice.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 17/05/24.
//

import Virtualization


/// This typealias allows for cleaner-looking code
typealias RosettaDevice = VZLinuxRosettaDirectoryShare

extension RosettaDevice {
    
    /// This method can create an Apple Rosetta specific shared directory mount between the host and the guest systems.
    static func createDevice() throws -> FileSystemDevice {
                
        switch RosettaDevice.availability {
        case .installed:
            
            // We try to initialize the directory share and enable caching options
            let rosettaDirectoryShare = try RosettaDevice()
            try rosettaDirectoryShare.setCachingOptions(.abstractSocket("rosettaSocket"))
            
            // Now we create the actual sharing device
            let sharingDevice = FileSystemDevice(tag: "ROSETTA_SHARE")
            sharingDevice.share = rosettaDirectoryShare
            
            return sharingDevice
        default:
            
            // TBD Handling Rosetta installation
            
            // Rosetta is not available
            throw VZKitError.rosetta
        }
    }
}
