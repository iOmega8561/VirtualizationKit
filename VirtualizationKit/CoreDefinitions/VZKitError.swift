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
    
    // "Something blew up in Virtualization.framework"
    case appleLimitExceeded
    
    // "Something went wrong writing/reading files"
    case auxiliaryFailedSetup
    case diskImageFailedSetup
    case machineIdCorrupt
    case machineIdMissing
    case missingMacImage
    
    // Features
    case unavailableFeature(_ feature: VZKitFeature)
    case permissionDenied(_ feature: VZKitFeature)
    case unsupportedFeature(_ feature: VZKitFeature)
    case usbDeviceNotFound(_ id: UUID)
    
    // Networking
    case invalidMacAddress(_ macAddress: String)
    case bridgeNicUnavailable(_ id: String?)
    
    // Configuration/Generic
    case macUnsupportedImage
    case macUnsupportedHost
    case wrongMacImageVersion(_ expected: OperatingSystem.Version,
                              _ actual: OperatingSystem.Version)

    public var errorDescription: String? { self.errorLocale.value }
    
    private var errorLocale: VZKitLocale {
        
        switch self {
        
        case .appleLimitExceeded: .init("error-appleLimitExceeded")
                
        case .auxiliaryFailedSetup: .init("error-auxiliaryFailedSetup")
        case .diskImageFailedSetup: .init("error-diskImageFailedSetup")
        case .machineIdCorrupt: .init("error-machineIdCorrupt")
        case .machineIdMissing: .init("error-machineIdMissing")
        case .missingMacImage: .init("error-missingMacImage")
                
        case .permissionDenied(let feature): .init("error-permissionDenied", feature)
        case .unavailableFeature(let feature): .init("error-unavailableFeature", feature)
        case .unsupportedFeature(let feature): .init("error-unsupportedFeature", feature)
        case .usbDeviceNotFound(let id): .init("error-usbDeviceNotFound", id.uuidString)
                    
        case .invalidMacAddress(let macAddress): .init("error-invalidMacAddress", macAddress)
        case .bridgeNicUnavailable(let id):
            id != nil ? .init("error-bridgeNicUnavailable", id!) :
                        .init("error-bridgeNoNicsAvailable")
                    
        case .macUnsupportedImage: .init("error-macUnsupportedImage")
        case .macUnsupportedHost: .init("error-macUnsupportedHost")
        case .wrongMacImageVersion(let expected, let actual):
                .init("error-wrongMacImageVersion", expected, actual)
        }
    }
}
