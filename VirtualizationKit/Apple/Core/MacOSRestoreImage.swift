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
//  MacOSRestoreImage.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 13/11/24.
//

import Virtualization

/// A macOS restore image (IPSW), described by what Virtualization.framework reads from it.
///
/// Load one to show it to the user, to check whether this Mac can run it, or to create the options of a
/// macOS virtual machine:
///
/// ```swift
/// let image = try await MacOSRestoreImage.load(from: ipswURL)
///
/// guard image.isSupported else { /* this Mac cannot run it */ }
/// print("macOS \(image.version) (\(image.buildVersion))")
///
/// let options = AppleMachineOptions(platform: try .macOS(restoreImage: image))
/// ```
///
/// The image is read once, when it is loaded. The value only keeps what was read, so it is `Sendable` and
/// can be passed anywhere; `VZMacOSRestoreImage` itself never leaves the queue Virtualization.framework
/// delivers it on.
public struct MacOSRestoreImage: Sendable, Hashable {

    /// What a virtual machine installed from an image needs, on this Mac.
    public struct Requirements: Sendable, Hashable {

        /// The smallest number of processors the virtual machine can have.
        public let minimumCPUCount: Int

        /// The smallest amount of memory the virtual machine can have, in bytes.
        public let minimumMemorySize: UInt64
    }

    /// The location the image was loaded from.
    public let url: URL

    /// The version of macOS the image installs.
    public let version: AppleMachineOptions.Version

    /// The build of macOS the image installs, such as "24A335".
    public let buildVersion: String

    /// Whether this Mac can run macOS installed from the image.
    public let isSupported: Bool

    /// The requirements of the most capable configuration this Mac and the image both support, or `nil` if
    /// they support none.
    public let requirements: Requirements?

    /// The data representation of the hardware model of that configuration. Used to create the virtual Mac.
    let hardwareModel: Data?

    /// Loads the restore image at a location.
    ///
    /// - Parameter url: The location of the IPSW file. Inside the App Sandbox, it has to be reachable,
    ///   such as a URL an open panel just returned.
    /// - Returns: What the image says about itself.
    /// - Throws: The error of Virtualization.framework if the file is not a valid restore image.
    public static func load(from url: URL) async throws -> MacOSRestoreImage {

        try await withCheckedThrowingContinuation { continuation in

            VZMacOSRestoreImage.load(from: url) { result in

                switch result {
                case let .failure(error):
                    continuation.resume(throwing: error)

                case let .success(image):
                    // Read here, where the image is delivered; only plain values leave this queue.
                    let configuration = image.mostFeaturefulSupportedConfiguration

                    continuation.resume(returning: MacOSRestoreImage(
                        url: url,
                        version: .init(image.operatingSystemVersion),
                        buildVersion: image.buildVersion,
                        isSupported: image.isSupported,
                        requirements: configuration.map {
                            Requirements(
                                minimumCPUCount: $0.minimumSupportedCPUCount,
                                minimumMemorySize: $0.minimumSupportedMemorySize
                            )
                        },
                        hardwareModel: configuration?.hardwareModel.dataRepresentation
                    ))
                }
            }
        }
    }
}
