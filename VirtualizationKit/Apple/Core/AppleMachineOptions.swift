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

import Virtualization

/// Settings that only make sense for the Apple backend.
///
/// Virtualization.framework runs two kinds of machine that have nothing in common below the surface:
/// a generic one, booted by UEFI firmware, for Linux guests, and a virtual Mac for macOS guests. Which
/// of the two a template is built into is the one thing the template cannot say in backend-neutral
/// terms, so it is stated here.
///
/// ```swift
/// // A Linux guest: the default.
/// let linux = try await AppleVirtualMachine(template: template)
///
/// // A macOS guest, installed from a restore image the user picked.
/// let options = AppleMachineOptions(platform: try await .macOS(restoreImageAt: ipswURL))
/// let mac = try await AppleVirtualMachine(template: template, options: options)
/// ```
public struct AppleMachineOptions: MachineOptions {

    // MARK: - Supporting Types

    /// The kind of machine a guest runs on.
    public enum Platform: Transferable {

        /// A generic machine booted by UEFI firmware, for Linux guests.
        case linux

        /// A virtual Mac, for macOS guests.
        ///
        /// - Parameters:
        ///   - version: The macOS version of the guest. Defaults to the minimum supported version
        ///     defined in VirtualizationKit. Some devices are only offered to guests that are recent
        ///     enough to have a driver for them.
        ///   - restoreImage: A security-scoped bookmark to the IPSW restore image macOS is installed from.
        ///     It is needed the first time the virtual machine is built and whenever macOS is installed;
        ///     an installed machine works without it.
        case macOS(version: Version = VirtualizationKit.macOSGuestMinVersion, restoreImage: Data? = nil)

        /// The name of the operating system the platform is meant for. Not localized.
        public var displayName: String {
            switch self {
            case .linux: "Linux"
            case .macOS: "macOS"
            }
        }

        /// The version of the guest operating system, where the platform has a notion of one.
        public var version: Version? {
            switch self {
            case .linux: nil
            case .macOS(let version, _): version
            }
        }

        /// Describes the virtual Mac a loaded restore image installs.
        ///
        /// Records a security-scoped bookmark to the image, so that the result can be persisted and still
        /// finds the image after the application is relaunched. Call it while the image is reachable, as
        /// with `DiskImage.Location.external(fileAt:)`.
        ///
        /// - Parameter restoreImage: The restore image, as `MacOSRestoreImage.load(from:)` returned it.
        /// - Returns: A `macOS` platform for the version of the image, referring to the image.
        /// - Throws: The underlying error if no bookmark can be created for the image.
        public static func macOS(restoreImage: MacOSRestoreImage) throws -> Platform {
            .macOS(
                version: restoreImage.version,
                restoreImage: try restoreImage.url.bookmarkData(
                    options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess]
                )
            )
        }

        /// Describes the virtual Mac a restore image installs, loading the image first.
        ///
        /// To show the image to the user before creating the machine, load it with
        /// `MacOSRestoreImage.load(from:)` and use `macOS(restoreImage:)` instead.
        ///
        /// - Parameter location: The location of the IPSW restore image.
        /// - Returns: A `macOS` platform for the version of the image, referring to the image.
        /// - Throws: The underlying error if the location does not hold a valid restore image, or if no
        ///   bookmark can be created for it.
        public static func macOS(restoreImageAt location: URL) async throws -> Platform {
            try macOS(restoreImage: await MacOSRestoreImage.load(from: location))
        }
    }

    // MARK: - Properties

    /// The options a virtual machine is created with when none are given: a Linux guest.
    public static var `default`: Self { .init() }

    /// The kind of machine the guest runs on. Defaults to `.linux`.
    public var platform: Platform

    // MARK: - Initializers

    /// Creates a set of options.
    ///
    /// - Parameter platform: The kind of machine the guest runs on.
    public init(platform: Platform = .linux) {
        self.platform = platform
    }
}
