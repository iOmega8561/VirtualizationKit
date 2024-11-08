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
    case captureDevicePermissionDenied
    case wrongMacImageVersion(_ expected: OperatingSystem.Version, _ actual: OperatingSystem.Version)
    case appleVMLimitExceeded
    case macOSGuestFeatureNotSupported(_ feature: String)
    case bridgeInterfaceNotAvailable(_ id: String)

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
            
        case .wrongMacImageVersion(let expected, let actual):
            return String(
                format: String(
                    localized: "error-configuration-wrongimgversion",
                    bundle: VirtualizationKit.bundle
                ),
                expected.major,
                expected.minor,
                actual.major,
                actual.minor
            )
            
        case .appleVMLimitExceeded:
            return String(
                localized: "error-applevz-limitexceeded",
                bundle: VirtualizationKit.bundle
            )
            
        case .macOSGuestFeatureNotSupported(let feature):
            return String(
                format: String(
                    localized: "error-configuration-unsopportedfeature",
                    bundle: VirtualizationKit.bundle
                ),
                feature
            )
        case .bridgeInterfaceNotAvailable(let id):
            return String(
                format: String(
                    localized: "error-configuration-netinterface",
                    bundle: VirtualizationKit.bundle
                ),
                id
            )
        }
    }
}
