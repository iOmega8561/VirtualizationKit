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
    case hostFeatureUnsupported(_ feature: String)
    case guestFeatureNotSupported(_ feature: String)
    case rosettaUnavailable
    case auxiliaryStorage
    case macUnsupportedImage
    case macUnsupportedHost
    case missingMacImage
    case notInitialized
    case captureDevicePermissionDenied
    case wrongMacImageVersion(_ expected: OperatingSystem.Version, _ actual: OperatingSystem.Version)
    case appleVMLimitExceeded
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
            
        case .notInitialized:
            return VirtualizationKit.localized("error-machine-notinizialized")
            
        case .captureDevicePermissionDenied:
            return VirtualizationKit.localized("error-configuration-capturedevice")
            
        case .wrongMacImageVersion(let expected, let actual):
            return .init(format: VirtualizationKit.localized("error-configuration-wrongimgversion"),
                         expected.major,
                         expected.minor,
                         actual.major,
                         actual.minor)
            
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
        }
    }
}
