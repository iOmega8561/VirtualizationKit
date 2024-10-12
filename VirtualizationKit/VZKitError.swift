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
//  VZKitError.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 12/10/24.
//

import Foundation

enum VZKitError: LocalizedError {
    case mainDisk
    case machineId
    case machineIdRetrieve
    case efiStore
    case usbDisk
    case rosetta
    case auxiliaryStorage
    case macUnsupportedImage
    case macUnsupportedHost
    case missingMacImage
    case notInitialized

    public var errorDescription: String? {
        
        switch self {
        case .mainDisk:
            return String(localized: "error-configuration-maindisk")
            
        case .machineId:
            return String(localized: "error-configuration-machineid")
            
        case .machineIdRetrieve:
            return String(localized: "error-configuration-machineid-retrieve")
            
        case .efiStore:
            return String(localized: "error-configuration-efistore")
        
        case .usbDisk:
            return String(localized: "error-configuration-usbdisk")
        
        case .rosetta:
            return String(localized: "error-configuration-rosetta")
        
        case .auxiliaryStorage:
            return String(localized: "error-configuration-auxstorage")
        
        case .macUnsupportedImage:
            return String(localized: "error-configuration-macimage")
        
        case .macUnsupportedHost:
            return String(localized: "error-configuration-machost")
            
        case .missingMacImage:
            return String(localized: "error-installer-macimage")
        
        case .notInitialized:
            return String(localized: "error-machine-notinizialized")
        }
    }
}
