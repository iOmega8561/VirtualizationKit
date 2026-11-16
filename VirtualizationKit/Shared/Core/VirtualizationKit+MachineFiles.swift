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

/// The files the machines of templates have on disk.
///
/// The machine of a template keeps its files in a directory of its own: the disks the framework manages,
/// firmware variables, TPM state, the identity of a virtual Mac, and the folder an Apple machine shares
/// with the guest. Disk images the user picked live elsewhere and are never touched here.
public extension TransferableTemplate {

    /// Deletes the files the machine of this template has on disk.
    ///
    /// Call it when the user deletes a virtual machine. Nothing happens if the machine has no files yet.
    ///
    /// ```swift
    /// try await template.deleteMachineFiles()
    /// ```
    ///
    /// - Important: This includes the folder an Apple machine shares with the guest, and whatever the guest
    ///   put there. Disk images outside the directory of the machine, such as installers or disks the user
    ///   picked, are kept.
    ///
    /// - Throws: `VZKitError.machineInUse` if a machine created from this template exists, here or in another
    ///   application; the error of the file system if a file cannot be removed.
    func deleteMachineFiles() async throws {
        let directory = await VirtualizationKit.machineDirectory(for: self)

        guard FileManager.default.fileExists(atPath: directory.path(percentEncoded: false)) else { return }

        let lock = try MachineLock(directory: directory)

        try withExtendedLifetime(lock) {
            try FileManager.default.removeItem(at: directory)
        }
    }
}

public extension DiskImage {

    /// The capacity of the disk, in bytes: the size the guest sees.
    ///
    /// For a disk the framework manages, this is the capacity the disk describes, which its file was created
    /// with; `resized(to:in:)` returns the disk with its new capacity, so store that result in the template.
    /// For an external image, the bookmark is resolved and the length of the file is returned, which for a raw
    /// image is its capacity.
    ///
    /// - Note: Images are sparse files. The space they take on disk grows as the guest writes, and is usually
    ///   much smaller than their capacity.
    ///
    /// - Returns: The capacity in bytes.
    /// - Throws: `VZKitError.diskImageUnreachable` if an external image cannot be located or read.
    func size() throws -> UInt64 {
        switch location {
        case .managed(let size):
            return size

        case .external(let bookmark):
            let access: SecurityScopedAccess
            do {
                access = try SecurityScopedAccess(resolving: bookmark)
            } catch {
                VZKitLogger.default.error("Disk \(id.uuidString): \(error.localizedDescription)")
                throw VZKitError.diskImageUnreachable(nil)
            }

            return try withExtendedLifetime(access) {
                let path = access.url.path(percentEncoded: false)
                guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
                      let size = (attributes[.size] as? NSNumber)?.uint64Value else {
                    throw VZKitError.diskImageUnreachable(access.url.lastPathComponent)
                }
                return size
            }
        }
    }

    /// Gives a disk the framework manages a larger capacity.
    ///
    /// The file grows at once, without taking space until the guest writes. The guest still sees its old
    /// partitions: extend them from inside the guest afterwards. Store the returned disk in the template, so
    /// that it describes the new capacity.
    ///
    /// ```swift
    /// template.storage[0] = try await template.storage[0].resized(to: 128 << 30, in: template)
    /// ```
    ///
    /// A disk whose file does not exist yet is only described with the new capacity; it is created with it.
    ///
    /// - Parameters:
    ///   - size: The new capacity, in bytes. It cannot be smaller than the current one.
    ///   - template: The template the disk belongs to, which locates its file.
    /// - Returns: The disk with its new capacity.
    /// - Throws:
    ///   - `VZKitError.invalidDiskImage` if the disk is not a managed disk of the template.
    ///   - `VZKitError.cannotShrinkDisk` if the new capacity is smaller than the current one.
    ///   - `VZKitError.machineInUse` if a machine created from the template exists.
    ///   - `VZKitError.diskImageFailedSetup` if the file cannot be resized.
    func resized(to size: UInt64, in template: some TransferableTemplate) async throws -> DiskImage {

        let disk = self

        guard case .managed = disk.location, template.storage.contains(where: { $0.id == disk.id }) else {
            VZKitLogger.default.error("Disk \(disk.id.uuidString) is not a managed disk of the template")
            throw VZKitError.invalidDiskImage(disk.id)
        }

        var resized = disk
        resized.location = .managed(size: size)

        let directory = await VirtualizationKit.machineDirectory(for: template)
        let file = DiskImageStore(directory: directory).managedURL(for: disk)

        guard FileManager.default.fileExists(atPath: file.path(percentEncoded: false)) else { return resized }

        let lock = try MachineLock(directory: directory)

        try withExtendedLifetime(lock) {
            let attributes = try FileManager.default.attributesOfItem(atPath: file.path(percentEncoded: false))
            let current = (attributes[.size] as? NSNumber)?.uint64Value ?? 0

            guard size >= current else { throw VZKitError.cannotShrinkDisk(disk.id) }
            guard size > current else { return }

            do {
                let handle = try FileHandle(forWritingTo: file)
                defer { try? handle.close() }
                try handle.truncate(atOffset: size)
            } catch {
                VZKitLogger.default.error("Disk \(disk.id.uuidString) cannot be resized: \(error.localizedDescription)")
                throw VZKitError.diskImageFailedSetup
            }
        }

        return resized
    }
}

extension _VirtualizationKit {

    /// The directory holding the files of the machine of a template, shared by both backends.
    @MainActor
    func machineDirectory(for template: some TransferableTemplate) -> URL {
        supportDirectory.appendingPathComponent(template.id.uuidString, isDirectory: true)
    }
}
