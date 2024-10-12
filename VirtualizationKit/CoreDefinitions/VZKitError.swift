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
            return String(
                localized: "error-configuration-maindisk",
                bundle: Bundle(identifier: "giusepperocco.VirtualizationKit")
            )
            
        case .machineId:
            return String(
                localized: "error-configuration-machineid",
                bundle: Bundle(identifier: "giusepperocco.VirtualizationKit")
            )
            
        case .machineIdRetrieve:
            return String(
                localized: "error-configuration-machineid-retrieve",
                bundle: Bundle(identifier: "giusepperocco.VirtualizationKit")
            )
            
        case .efiStore:
            return String(
                localized: "error-configuration-efistore",
                bundle: Bundle(identifier: "giusepperocco.VirtualizationKit")
            )
            
        case .usbDisk:
            return String(
                localized: "error-configuration-usbdisk",
                bundle: Bundle(identifier: "giusepperocco.VirtualizationKit")
            )
            
        case .rosetta:
            return String(
                localized: "error-configuration-rosetta",
                bundle: Bundle(identifier: "giusepperocco.VirtualizationKit")
            )
            
        case .auxiliaryStorage:
            return String(
                localized: "error-configuration-auxstorage",
                bundle: Bundle(identifier: "giusepperocco.VirtualizationKit")
            )
            
        case .macUnsupportedImage:
            return String(
                localized: "error-configuration-macimage",
                bundle: Bundle(identifier: "giusepperocco.VirtualizationKit")
            )
            
        case .macUnsupportedHost:
            return String(
                localized: "error-configuration-machost",
                bundle: Bundle(identifier: "giusepperocco.VirtualizationKit")
            )
            
        case .missingMacImage:
            return String(
                localized: "error-installer-macimage",
                bundle: Bundle(identifier: "giusepperocco.VirtualizationKit")
            )
            
        case .notInitialized:
            return String(
                localized: "error-machine-notinizialized",
                bundle: Bundle(identifier: "giusepperocco.VirtualizationKit")
            )
        }
    }
}
