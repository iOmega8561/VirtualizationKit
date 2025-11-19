//
//  Copyright 2025 Giuseppe Rocco
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
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
    case coreFilesTampered
    case coreFilesMissing
    case missingMacImage
    
    // Features
    case unavailableFeature(_ capability: OptionalCapability)
    case permissionDenied(_ capability: OptionalCapability)
    case unsupportedFeature(_ capability: OptionalCapability)
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
        case .coreFilesTampered: .init("error-coreFilesTampered")
        case .coreFilesMissing: .init("error-coreFilesMissing")
        case .missingMacImage: .init("error-missingMacImage")
                
        case .permissionDenied(let capability): .init("error-permissionDenied", capability)
        case .unavailableFeature(let capability): .init("error-unavailableFeature", capability)
        case .unsupportedFeature(let capability): .init("error-unsupportedFeature", capability)
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
