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
    case machineIdCorrupt
    case machineIdMissing
    case hostFeatureUnsupported(_ feature: String)
    case guestFeatureNotSupported(_ feature: String)
    case rosettaUnavailable
    case auxiliaryStorage
    case macUnsupportedImage
    case macUnsupportedHost
    case missingMacImage
    case captureDevicePermissionDenied
    case wrongMacImageVersion(_ expected: OperatingSystem.Version, _ actual: OperatingSystem.Version)
    case appleVMLimitExceeded
    case bridgeInterfaceNotAvailable(_ id: String?)
    case invalidMacAddress(_ macAddress: String)
    case usbDeviceNotFound(_ id: UUID)

    public var errorDescription: String? {
        
        switch self {
        case .mainDisk:
            return VirtualizationKit.localized("error-configuration-maindisk")
            
        case .machineIdCorrupt:
            return VirtualizationKit.localized("error-configuration-machineid-corrupt")
            
        case .machineIdMissing:
            return VirtualizationKit.localized("error-configuration-machineid-missing")
            
        case .hostFeatureUnsupported(let feature):
            return .init(format: VirtualizationKit.localized("error-configuration-host-feature-unsupported"),
                         feature)
            
        case .guestFeatureNotSupported(let feature):
            return .init(format: VirtualizationKit.localized("error-configuration-guest-feature-unsupported"),
                         feature)
            
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
            
        case .captureDevicePermissionDenied:
            return VirtualizationKit.localized("error-configuration-capturedevice")
            
        case .wrongMacImageVersion(let expected, let actual):
            return .init(format: VirtualizationKit.localized("error-configuration-wrongimgversion"),
                         expected.description,
                         actual.description)
            
        case .appleVMLimitExceeded:
            return .init(format: VirtualizationKit.localized("error-applevz-limitexceeded"),
                         VirtualizationKit.appleMaxVMs)
            
        case .bridgeInterfaceNotAvailable(let id):
            guard let id else {
                return VirtualizationKit.localized("error-configuration-netinterfaces")
            }
            
            return .init(format: VirtualizationKit.localized("error-configuration-netinterface"), id)
            
        case .invalidMacAddress(let macAddress):
            return .init(format: VirtualizationKit.localized("error-configuration-macaddress"), macAddress)
            
        case .usbDeviceNotFound(let id):
            return .init(format: VirtualizationKit.localized("error-usbdev-notfound"), id.uuidString)
        }
    }
}
