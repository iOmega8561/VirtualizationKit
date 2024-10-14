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

import Foundation

public final class _VirtualizationKit: Sendable {
    
    /// The version string of this framework
    public let version: String = "1.0"
    
    /// The maximum amount of macOS virtual machines that can run simultaneously.
    /// Unfortunately Apple Virtualization Framework limits this amount to two VMs at once :(
    public let appleMaxVMs: Int = 2
    
    /// The resource bundle of this framework,
    /// to get assets and localized strings from here and not the main bundle
    public let bundle: Bundle? = .init(identifier: "giusepperocco.VirtualizationKit")
    
    /// The host machine path where all the VM data should be located.
    /// The application that uses this framework should set this value to something else.
    /// This property will only be used internally.
    ///
    /// - Important: Pinned to `@MainActor` for thread safe access and `Sendable` conformance.
    @MainActor private(set) var bundlePath: String = NSHomeDirectory() + "/VirtualizationKit.bundle/"
    
    /// The public setter method for `bundlePath`. The application that wants to override
    /// `bundlePath` needs to call this setter providing a `String` path
    ///
    /// - Important: Executes on `@MainActor` to be able to edit `bundlePath` synchronously
    ///
    /// - Parameters:
    ///   - path: A `String` representing the destination path.
    @MainActor public func setBundlePath(_ path: String) { bundlePath = path }
    
    fileprivate init() {}
}

public let VirtualizationKit: _VirtualizationKit = .init()
