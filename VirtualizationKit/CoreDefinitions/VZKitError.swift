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
    case rosettaUnsupported
    case rosettaUnavailable
    case auxiliaryStorage
    case macUnsupportedImage
    case macUnsupportedHost
    case missingMacImage
    case notInitialized
    case captureDevicePermissionDenied
    case wrongMacImageVersion(_ expected: OperatingSystem.Version, _ actual: OperatingSystem.Version)
    case appleVMLimitExceeded
    case macOSGuestFeatureNotSupported(_ feature: String)
    case bridgeInterfaceNotAvailable(_ id: String?)
    case invalidMacAddress(_ macAddress: String)

    public var errorDescription: String? {
        
        switch self {
        case .mainDisk:
            return VirtualizationKit.localized("error-configuration-maindisk")
            
        case .machineId:
            return VirtualizationKit.localized("error-configuration-machineid")
            
        case .machineIdRetrieve:
            return VirtualizationKit.localized("error-configuration-machineid-retrieve")
            
        case .efiStore:
            return VirtualizationKit.localized("error-configuration-efistore")
            
        case .usbDisk:
            return VirtualizationKit.localized("error-configuration-usbdisk")
            
        case .rosettaUnsupported:
            return VirtualizationKit.localized("error-configuration-rosettaunsupported")
        
        case .rosettaUnavailable:
            return VirtualizationKit.localized("error-configuration-rosettaunavailable")
            
        case .auxiliaryStorage:
            return VirtualizationKit.localized("error-configuration-auxstorage")
            
        case .macUnsupportedImage:
            return VirtualizationKit.localized("error-configuration-macimage")
            
        case .macUnsupportedHost:
            return VirtualizationKit.localized("error-configuration-machost")
            
        case .missingMacImage:
            return VirtualizationKit.localized("error-installer-macimage")
            
        case .notInitialized:
            return VirtualizationKit.localized("error-machine-notinizialized")
            
        case .captureDevicePermissionDenied:
            return VirtualizationKit.localized("error-configuration-capturedevice")
            
        case .wrongMacImageVersion(let expected, let actual):
            return .init(
                format: VirtualizationKit.localized("error-configuration-wrongimgversion"),
                expected.major,
                expected.minor,
                actual.major,
                actual.minor
            )
            
        case .appleVMLimitExceeded:
            return VirtualizationKit.localized("error-applevz-limitexceeded")
            
        case .macOSGuestFeatureNotSupported(let feature):
            return .init(format: VirtualizationKit.localized("error-configuration-unsopportedfeature"), feature)
            
        case .bridgeInterfaceNotAvailable(let id):
            guard let id else {
                return VirtualizationKit.localized("error-configuration-netinterfaces")
            }
            
            return .init(format: VirtualizationKit.localized("error-configuration-netinterface"), id)
        
        case .invalidMacAddress(let macAddress):
            return .init(format: VirtualizationKit.localized("error-configuration-macaddress"), macAddress)
        }
    }
}
