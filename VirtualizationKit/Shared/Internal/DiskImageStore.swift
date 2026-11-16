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

/// A disk of a template, located on the host and ready to be opened.
struct ProvisionedDiskImage: Sendable {

    /// The disk as the template describes it.
    let image: DiskImage

    /// The file backing the disk.
    let url: URL

    /// Keeps an external image reachable inside the App Sandbox. `nil` for managed images, which live
    /// in the application's own container.
    let access: SecurityScopedAccess?
}

/// Turns the disks of a template into files.
///
/// Both backends keep the files of a machine in one directory and treat disks the same way up to the
/// point where a device is created for them: a managed disk is a sparse file named after its
/// identifier, created on first use; an external one is whatever its bookmark resolves to.
struct DiskImageStore: Sendable {

    /// The directory holding the files of the virtual machine.
    let directory: URL

    /// The location of a managed disk.
    ///
    /// - Parameter image: A disk whose location is `managed`.
    /// - Returns: The location of its file, whether or not it exists yet.
    func managedURL(for image: DiskImage) -> URL {
        directory.appendingPathComponent(image.managedFileName, isDirectory: false)
    }

    /// Locates the file of a disk, creating it if it is managed and missing.
    ///
    /// - Parameter image: The disk to provision.
    /// - Returns: The disk together with its file and, for an external image, the guard that keeps the
    ///   file reachable. The caller holds on to the guard for as long as the file is in use.
    /// - Throws: `VZKitError.diskImageFailedSetup` if a managed image cannot be created, or
    ///   `VZKitError.diskImageUnreachable` if an external one cannot be found.
    func provision(_ image: DiskImage) throws -> ProvisionedDiskImage {
        switch image.location {
        case .managed(let size):
            let url = managedURL(for: image)
            try Self.createSparseFile(at: url, size: size)
            return .init(image: image, url: url, access: nil)

        case .external(let bookmark):
            let access: SecurityScopedAccess
            do {
                access = try SecurityScopedAccess(resolving: bookmark)
            } catch {
                VZKitLogger.default.error("Disk \(image.id.uuidString): \(error.localizedDescription)")
                throw VZKitError.diskImageUnreachable(nil)
            }

            guard FileManager.default.fileExists(atPath: access.url.path(percentEncoded: false)) else {
                throw VZKitError.diskImageUnreachable(access.url.lastPathComponent)
            }
            return .init(image: image, url: access.url, access: access)
        }
    }

    /// Locates the files of several disks, keeping their order.
    ///
    /// - Parameter storage: The disks to provision.
    /// - Returns: One provisioned disk per element of `storage`.
    /// - Throws: The error of the first disk that cannot be provisioned.
    func provision(_ storage: [DiskImage]) throws -> [ProvisionedDiskImage] {
        try storage.map { try provision($0) }
    }

    /// Creates a sparse file of a given size, unless a file already exists at the location.
    ///
    /// - Parameters:
    ///   - url: The location of the file.
    ///   - size: The size of the file in bytes. No storage is allocated up front.
    /// - Throws: `VZKitError.diskImageFailedSetup` if the file cannot be created or sized.
    static func createSparseFile(at url: URL, size: UInt64) throws {
        let path = url.path(percentEncoded: false)

        guard !FileManager.default.fileExists(atPath: path) else { return }

        guard FileManager.default.createFile(atPath: path, contents: nil, attributes: nil) else {
            throw VZKitError.diskImageFailedSetup
        }

        do {
            let fileHandle = try FileHandle(forWritingTo: url)
            defer { try? fileHandle.close() }
            try fileHandle.truncate(atOffset: size)
        } catch {
            // A file of the wrong size would be picked up as a valid disk by the next attempt.
            try? FileManager.default.removeItem(at: url)
            throw VZKitError.diskImageFailedSetup
        }
    }
}
