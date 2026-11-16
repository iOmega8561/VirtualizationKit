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
public extension _VirtualizationKit {

    /// Deletes the files of the machine of a template.
    ///
    /// Call it when the user deletes a virtual machine. Nothing happens if the machine has no files yet.
    ///
    /// - Important: This includes the folder an Apple machine shares with the guest, and whatever the guest
    ///   put there. Disk images outside the directory of the machine, such as installers or disks the user
    ///   picked, are kept.
    ///
    /// - Parameter template: The template whose machine is deleted.
    /// - Throws: `VZKitError.machineInUse` if a machine created from the template exists, here or in another
    ///   application; the error of the file system if a file cannot be removed.
    func deleteFiles(of template: some TransferableTemplate) async throws {
        let directory = await machineDirectory(for: template)

        guard FileManager.default.fileExists(atPath: directory.path(percentEncoded: false)) else { return }

        let lock = try MachineLock(directory: directory)

        try withExtendedLifetime(lock) {
            try FileManager.default.removeItem(at: directory)
        }
    }

    /// Gives a disk the framework manages a larger capacity.
    ///
    /// The file grows at once, without taking space until the guest writes. The guest still sees its old
    /// partitions: extend them from inside the guest afterwards. Store the returned disk in the template, so
    /// that it describes the new capacity.
    ///
    /// A disk whose file does not exist yet is only described with the new capacity; it is created with it.
    ///
    /// - Parameters:
    ///   - disk: A managed disk of the template.
    ///   - template: The template the disk belongs to.
    ///   - size: The new capacity, in bytes. It cannot be smaller than the current one.
    /// - Returns: The disk with its new capacity.
    /// - Throws:
    ///   - `VZKitError.invalidDiskImage` if the disk is not a managed disk of the template.
    ///   - `VZKitError.cannotShrinkDisk` if the new capacity is smaller than the current one.
    ///   - `VZKitError.machineInUse` if a machine created from the template exists.
    ///   - `VZKitError.diskImageFailedSetup` if the file cannot be resized.
    func resize(
        _ disk: DiskImage,
        of template: some TransferableTemplate,
        to size: UInt64
    ) async throws -> DiskImage {

        guard case .managed = disk.location, template.storage.contains(where: { $0.id == disk.id }) else {
            VZKitLogger.default.error("Disk \(disk.id.uuidString) is not a managed disk of the template")
            throw VZKitError.invalidDiskImage(disk.id)
        }

        var resized = disk
        resized.location = .managed(size: size)

        let directory = await machineDirectory(for: template)
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
