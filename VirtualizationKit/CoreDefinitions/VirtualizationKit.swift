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
//  VirtualizationKit.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 13/10/24.
//

@_exported import Foundation

public final class _VirtualizationKit: Sendable {
    
    /// The bundle identifier of this framework
    public let bundleIdentifier: String = "giusepperocco.VirtualizationKit"
    
    /// The version string of this framework
    public let version: String = "1.4.1"
    
    /// The minimum macOS version supported as a guest operating system
    public let macOSGuestMinVersion: OperatingSystem.Version = .init(major: 12, minor: 4, patch: 0)
    
    /// The maximum amount of macOS virtual machines that can run simultaneously.
    /// Unfortunately Apple Virtualization Framework limits this amount to two VMs at once :(
    public let appleMaxVMs: Int = 2
    
    /// The resource bundle of this framework,
    /// to get assets and localized strings from here and not the main bundle
    public let bundle: Bundle?
    
    /// The host machine path where all the VM data should be located.
    /// The application that uses this framework should set this value to something else.
    /// This property will only be used internally.
    ///
    /// - Important: Pinned to `@MainActor` for thread safe access and `Sendable` conformance.
    @MainActor private(set) var supportDirectory: URL
    
    /// The public setter method for `bundlePath`. The application that wants to override
    /// `bundlePath` needs to call this setter providing a `String` path
    ///
    /// - Important: Executes on `@MainActor` to be able to edit `bundlePath` synchronously
    ///
    /// - Parameters:
    ///   - url: A `URL` representing the destination path.
    @MainActor public func setSupportDirectory(_ url: URL) { supportDirectory = url }
    
    internal func localized(_ key: String.LocalizationValue) -> String {
        return .init(localized: key, bundle: VirtualizationKit.bundle)
    }
    
    fileprivate init() {
        self.bundle = .init(identifier: bundleIdentifier)
        self.supportDirectory = .applicationSupportDirectory.appendingPathComponent(bundleIdentifier)
    }
}

@available(macOS 15.0, *)
extension _VirtualizationKit {
    
    /// Determines whether or not the Nested Virtualization feature is supported by the Host Mac
    /// - Note: This is only available starting with macOS 15
    public var isNestedVirtualizationSupported: Bool {
        GenericPlatform.isNestedVirtualizationSupported
    }
}

public let VirtualizationKit: _VirtualizationKit = .init()
