//
//  VZKitError.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 12/10/24.
//

import Foundation

extension String {
    
    static func vzKit(_ key: String.LocalizationValue, _ arguments: CVarArg...) -> String {
        arguments.count != 0 ? .init(format: VirtualizationKit.localized(key), arguments) :
                               VirtualizationKit.localized(key)
    }
}

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
    case hostFeatureUnsupported(_ feature: String)
    case guestFeatureUnsupported(_ feature: String)
    case invalidMacAddress(_ macAddress: String)
    case usbDeviceNotFound(_ id: UUID)
    
    // Configuration - Generic
    case macUnsupportedImage
    case macUnsupportedHost
    case wrongMacImageVersion(_ expected: VZKitOperatingSystem.Version,
                              _ actual: VZKitOperatingSystem.Version)

    public var errorDescription: String {
        
        switch self {
        // "Something blew up in Virtualization.framework"
        case .appleLimitExceeded: .vzKit("error-appleLimitExceeded", VirtualizationKit.appleMaxVMs)
        
        // "Something went wrong with files on disk"
        case .auxiliaryFailedSetup: .vzKit("error-auxiliaryFailedSetup")
        case .diskImageFailedSetup: .vzKit("error-diskImageFailedSetup")
        case .machineIdCorrupt: .vzKit("error-machineIdCorrupt")
        case .machineIdMissing: .vzKit("error-machineIdMissing")
        case .missingMacImage: .vzKit("error-missingMacImage")
        
        // Configuration - Feature specific
        case .rosettaUnavailable: .vzKit("error-rosettaUnavailable")
        case .captureDevicePermissionDenied: .vzKit("error-captureDevicePermissionDenied")
        case .bridgeNicUnavailable(let id): if let id { .vzKit("error-bridgeNicUnavailable", id) }
                                            else { .vzKit("error-bridgeNoNicsAvailable") }
        case .hostFeatureUnsupported(let feature): .vzKit("error-hostFeatureUnsupported", feature)
        case .guestFeatureUnsupported(let feature): .vzKit("error-guestFeatureUnsupported", feature)
        case .invalidMacAddress(let macAddress): .vzKit("error-invalidMacAddress", macAddress)
        case .usbDeviceNotFound(let id): .vzKit("error-usbDeviceNotFound", id.uuidString)
        
        // Configuration - Generic
        case .macUnsupportedImage: .vzKit("error-macUnsupportedImage")
        case .macUnsupportedHost: .vzKit("error-macUnsupportedHost")
        case .wrongMacImageVersion(let expected, let actual): .vzKit("error-wrongMacImageVersion",
                                                                     expected.description,
                                                                     actual.description)
        }
    }
}
