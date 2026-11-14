//
//  Copyright 2026 Giuseppe Rocco
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
//  OperatingSystem+Apple.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 14/11/2026.
//

import Virtualization

public extension OperatingSystem {
    
    /// Asynchronously initializes an `OperatingSystem` from a disk image URL.
    ///
    /// This initializer attempts to load a macOS IPSW Restore Image from the provided URL. If successful,
    /// it infers a macOS operating system and extracts its version information. If the URL does not point
    /// to a valid macOS Restore Image, the initialization throws the underlying error.
    ///
    /// - Parameter location: The URL of the IPSW restore image used to detect the macOS version.
    init(fromImageAt location: URL) async throws {
        let macOSRestoreImage = try await VZMacOSRestoreImage.load(
            from: location
        )
        
        self = .macos(
            version: .init(macOSRestoreImage.operatingSystemVersion)
        )
    }
}
