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
//  RemovableUSBDisk.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 07/01/25.
//

import Foundation

@preconcurrency import Virtualization

@available(macOS 15.0, *)
public struct RemovableUSBDisk: Sendable {
    
    public let diskImageURL: URL
    
    public var description: String { diskImageURL.lastPathComponent }
    
    internal let vzUSBMassStorageDevice: VZUSBMassStorageDevice
    
    public init(diskImageUrl: URL) throws {
        
        self.vzUSBMassStorageDevice = try .init(
            configuration: .createDevice(diskImageUrl, .readOnly)
        )
        
        self.diskImageURL = diskImageUrl
    }
}

@available(macOS 15.0, *)
@VZKitGlobalActor extension VirtualMachine {
    
    public func attachRemovableUSBDisk(device: RemovableUSBDisk) async throws {
        
        guard let controller = vzVirtualMachine.usbControllers.first else {
            throw VZKitError.guestFeatureNotSupported("XHCI USB Controller")
        }
        
        try await controller.attach(device: device.vzUSBMassStorageDevice)
    }
    
    public func detachRemovableUSBDisk(device: RemovableUSBDisk) async throws {
        
        guard let controller = vzVirtualMachine.usbControllers.first else {
            throw VZKitError.guestFeatureNotSupported("XHCI USB Controller")
        }
        
        try await controller.detach(device: device.vzUSBMassStorageDevice)
    }
}
