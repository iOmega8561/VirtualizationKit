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
    case captureDevicePermissionDenied

    public var errorDescription: String? {
        
        switch self {
        case .mainDisk:
            return String(
                localized: "error-configuration-maindisk",
                bundle: VirtualizationKit.bundle
            )
            
        case .machineId:
            return String(
                localized: "error-configuration-machineid",
                bundle: VirtualizationKit.bundle
            )
            
        case .machineIdRetrieve:
            return String(
                localized: "error-configuration-machineid-retrieve",
                bundle: VirtualizationKit.bundle
            )
            
        case .efiStore:
            return String(
                localized: "error-configuration-efistore",
                bundle: VirtualizationKit.bundle
            )
            
        case .usbDisk:
            return String(
                localized: "error-configuration-usbdisk",
                bundle: VirtualizationKit.bundle
            )
            
        case .rosetta:
            return String(
                localized: "error-configuration-rosetta",
                bundle: VirtualizationKit.bundle
            )
            
        case .auxiliaryStorage:
            return String(
                localized: "error-configuration-auxstorage",
                bundle: VirtualizationKit.bundle
            )
            
        case .macUnsupportedImage:
            return String(
                localized: "error-configuration-macimage",
                bundle: VirtualizationKit.bundle
            )
            
        case .macUnsupportedHost:
            return String(
                localized: "error-configuration-machost",
                bundle: VirtualizationKit.bundle
            )
            
        case .missingMacImage:
            return String(
                localized: "error-installer-macimage",
                bundle: VirtualizationKit.bundle
            )
            
        case .notInitialized:
            return String(
                localized: "error-machine-notinizialized",
                bundle: VirtualizationKit.bundle
            )
        
        case .captureDevicePermissionDenied:
            return String(
                localized: "error-configuration-capturedevice",
                bundle: VirtualizationKit.bundle
            )
        }
    }
}
