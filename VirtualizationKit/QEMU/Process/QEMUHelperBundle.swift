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

import Foundation

/// Locates the helper service and the emulator payload it carries.
///
/// The service is an XPC bundle that ships next to this framework. It contains the launcher, the
/// emulator libraries and the emulator's data files (firmware, option ROMs). Nothing about it is
/// hard-coded apart from its file name: its identifier, which doubles as the name the service is
/// reached under, is read from the bundle that is actually embedded. An application is therefore
/// free to re-identify and re-sign it.
struct QEMUHelperBundle: Sendable {

    /// The file name of the service bundle.
    static let bundleName = "QEMUHelper.xpc"

    /// The root of the service bundle.
    let url: URL

    /// The name under which the service is registered, i.e. the identifier of its bundle.
    let serviceName: String

    /// The directory holding the emulator's data files.
    var dataDirectory: URL {
        url.appendingPathComponent("Contents/Resources/qemu", isDirectory: true)
    }

    /// The location of an emulator library inside the service bundle.
    ///
    /// - Parameter name: The name of the library, without prefix and extension.
    /// - Returns: The location the library is expected at.
    func libraryURL(named name: String) -> URL {
        url.appendingPathComponent("Contents/Frameworks/lib\(name).dylib", isDirectory: false)
    }

    /// The location of a data file, checked for existence.
    ///
    /// - Parameter name: The file name, relative to the data directory.
    /// - Returns: The location of the file.
    /// - Throws: `VZKitError.qemuFirmwareMissing` if the file is not part of the bundle.
    func dataFile(named name: String) throws -> URL {
        let file = dataDirectory.appendingPathComponent(name, isDirectory: false)

        guard FileManager.default.fileExists(atPath: file.path(percentEncoded: false)) else {
            throw VZKitError.qemuFirmwareMissing(name)
        }

        return file
    }

    /// Finds the embedded service.
    ///
    /// The framework's own bundle is searched first, since that is where the build places the service.
    /// The application bundle is searched second, for applications that prefer to host it themselves.
    ///
    /// - Returns: The service bundle.
    /// - Throws: `VZKitError.qemuHelperUnavailable` if no service bundle with an identifier is found.
    static func locate() throws -> QEMUHelperBundle {

        var candidates: [URL] = []

        if let framework = VirtualizationKit.bundle?.bundleURL {
            candidates.append(framework.appendingPathComponent("XPCServices", isDirectory: true))
            candidates.append(framework.appendingPathComponent("Versions/Current/XPCServices", isDirectory: true))
        }

        candidates.append(Bundle.main.bundleURL.appendingPathComponent("Contents/XPCServices", isDirectory: true))

        for directory in candidates {
            let url = directory.appendingPathComponent(bundleName, isDirectory: true)

            guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)),
                  let identifier = Bundle(url: url)?.bundleIdentifier else { continue }

            return .init(url: url, serviceName: identifier)
        }

        throw VZKitError.qemuHelperUnavailable
    }
}
