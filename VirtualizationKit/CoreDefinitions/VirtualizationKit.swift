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
//  VirtualizationKit.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 13/10/24.
//

@_exported import Foundation

public final class _VirtualizationKit: Sendable {
    
    /// The bundle identifier of this framework
    public let bundleIdentifier: String = "com.giusepperocco.VirtualizationKit"
    
    /// The version string of this framework
    public let version: String = "1.4.5"
    
    /// The minimum macOS version supported as a guest operating system
    public let macOSGuestMinVersion: OperatingSystem.Version = .init(major: 12, minor: 4, patch: 0)
    
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
    
    fileprivate init() {
        self.bundle = .init(identifier: bundleIdentifier)
        self.supportDirectory = .applicationSupportDirectory.appendingPathComponent(bundleIdentifier)
    }
}

public let VirtualizationKit: _VirtualizationKit = .init()
