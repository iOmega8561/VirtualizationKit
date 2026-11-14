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
//  OperatingSystem.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 16/05/24.
//

import UniformTypeIdentifiers

/// The `OperatingSystem` enum specifies the supported operating systems for virtual machines
/// within VirtualizationKit.
///
/// Each case is associated with a set of metadata that defines its display name, expected
/// disk image file type, and, for macOS, an optional OS version. These metadata properties are exposed
/// via dedicated computed properties, allowing UI components and file handlers to easily access this
/// information without revealing the underlying implementation details.
///
/// Conformance to `Transferable` ensures seamless integration with other components in VirtualizationKit.
///
/// ### Usage Example
/// ```swift
/// let os: OperatingSystem = .macos(version: someVersion)
/// print(os.displayName)  // "macOS"
/// print(os.fileType)     // The disk image file type expected for macOS
/// ```
///
/// You can also initialize an instance from a disk image URL:
/// ```swift
/// do {
///     let detectedOS = try await OperatingSystem(fromImageAt: imageURL)
///     // Proceed with the detected macOS operating system
/// } catch {
///     // Handle error: the URL did not point to a valid macOS Restore Image
/// }
/// ```
public enum OperatingSystem: Transferable {
    
    /// Encapsulates display and file metadata for an operating system.
    private struct MetaData {
        /// The name to display in the UI.
        let displayName: String
        /// The expected disk image file type.
        let fileType: UTType
        /// The operating system version, if applicable.
        let version: Version?
    }
    
    /// Represents a Linux-based virtual machine.
    case linux
    
    /// Represents a macOS virtual machine.
    ///
    /// - Parameter version: The macOS version associated with the virtual machine. Defaults to the
    ///   minimum supported version defined in VirtualizationKit.
    case macos(version: Version = VirtualizationKit.macOSGuestMinVersion)
    
    /// Represents a Windows virtual machine.
    ///
    /// Only the QEMU backend runs Windows guests; it gives them the hardware Windows supports
    /// without additional drivers (see `QEMUVirtualMachine`). The Apple backend rejects them.
    case windows
    
    /// Provides the associated metadata for the operating system case.
    private var metaData: MetaData {
        switch self {
        case .linux: .init(
            displayName: "Linux",
            fileType: .diskImage,
            version: nil
        )
        case .macos(let version): .init(
            displayName: "macOS",
            fileType: .init(filenameExtension: "ipsw")!,
            version: version
        )
        case .windows: .init(
            displayName: "Windows",
            fileType: .diskImage,
            version: nil
        )}
    }
    
    /// The display name of the operating system.
    public var displayName: String { metaData.displayName }
    
    /// The expected disk image file type for the operating system.
    public var fileType: UTType { metaData.fileType }
    
    /// The operating system version, if applicable.
    public var version: Version? { metaData.version }
}
