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
    
    // "Something went wrong with files on disk"
    case auxiliaryFailedSetup
    case diskImageFailedSetup
    case machineIdCorrupt
    case machineIdMissing
    case missingMacImage
    
    // Configuration - Feature specific
    case rosettaUnavailable
    case captureDevicePermissionDenied
    case bridgeNicUnavailable(_ id: String?)
    case unsupportedFeature(_ feature: VZKitFeature)
    case invalidMacAddress(_ macAddress: String)
    case usbDeviceNotFound(_ id: UUID)
    
    // Configuration - Generic
    case macUnsupportedImage
    case macUnsupportedHost
    case wrongMacImageVersion(_ expected: VZKitOperatingSystem.Version,
                              _ actual: VZKitOperatingSystem.Version)

    public var errorDescription: String { self.localizedDescription }
    
    private var localizedDescription: VZKitLocale {
        
        switch self {
        // "Something blew up in Virtualization.framework"
        case .appleLimitExceeded: .init("error-appleLimitExceeded", VirtualizationKit.appleMaxVMs)
        
        // "Something went wrong with files on disk"
        case .auxiliaryFailedSetup: .init("error-auxiliaryFailedSetup")
        case .diskImageFailedSetup: .init("error-diskImageFailedSetup")
        case .machineIdCorrupt: .init("error-machineIdCorrupt")
        case .machineIdMissing: .init("error-machineIdMissing")
        case .missingMacImage: .init("error-missingMacImage")
        
        // Configuration - Feature specific
        case .rosettaUnavailable: .init("error-rosettaUnavailable")
        case .captureDevicePermissionDenied: .init("error-captureDevicePermissionDenied")
        case .invalidMacAddress(let macAddress): .init("error-invalidMacAddress", macAddress)
        case .unsupportedFeature(let feature): .init("error-unsupportedFeature", feature)
        case .usbDeviceNotFound(let id): .init("error-usbDeviceNotFound", id.uuidString)
        case .bridgeNicUnavailable(let id):
            if let id {
                .init("error-bridgeNicUnavailable", id)
                
            } else { .init("error-bridgeNoNicsAvailable") }
        
        // Configuration - Generic
        case .macUnsupportedImage: .init("error-macUnsupportedImage")
        case .macUnsupportedHost: .init("error-macUnsupportedHost")
        case .wrongMacImageVersion(let expected, let actual):
                .init("error-wrongMacImageVersion", expected, actual)
        }
    }
}
