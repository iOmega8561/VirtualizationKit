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
//  VZMacOSRestoreImage+Summary.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 13/11/24.
//

import Virtualization

/// What VirtualizationKit needs to know about a macOS restore image.
///
/// `VZMacOSRestoreImage` is not `Sendable`, and it is delivered on whatever queue Virtualization.framework
/// picks. Rather than claiming it is safe to pass around, the loader reads these values where the image
/// is delivered and returns them instead; the image itself never leaves that queue.
struct RestoreImageSummary: Sendable {

    /// The version of macOS the image installs.
    let version: AppleMachineOptions.Version

    /// The data representation of the hardware model of the most featureful configuration this host
    /// supports, or `nil` if the image offers none.
    let hardwareModel: Data?
}

extension VZMacOSRestoreImage {

    /// Loads the restore image at a location and summarizes it.
    ///
    /// - Parameter url: The location of the IPSW restore image.
    /// - Returns: The summary of the image.
    /// - Throws: The underlying error if the location does not hold a valid restore image.
    static func loadSummary(from url: URL) async throws -> RestoreImageSummary {

        try await withCheckedThrowingContinuation { continuation in

            VZMacOSRestoreImage.load(from: url) { result in

                switch result {
                case let .failure(error):
                    continuation.resume(throwing: error)

                case let .success(image):
                    continuation.resume(returning: RestoreImageSummary(
                        version: .init(image.operatingSystemVersion),
                        hardwareModel: image.mostFeaturefulSupportedConfiguration?.hardwareModel.dataRepresentation
                    ))
                }
            }
        }
    }
}
