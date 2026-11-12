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

/// The on-disk layout of a QEMU virtual machine.
///
/// A machine lives in the same per-template directory the Apple backend uses, inside the support
/// directory configured for the framework. Files that mean the same thing to both backends share a
/// name, so a guest installed on a raw disk image can in principle be booted by either one. Files
/// that are backend specific carry a `QEMU-` prefix and never collide.
struct QEMUMachineStorage: Sendable {

    /// The size every flash device of the `virt` machine must have.
    private static let armFlashSize: UInt64 = 64 * 1024 * 1024

    /// The directory holding all files of the machine.
    let directory: URL

    /// The main disk of the machine: a raw, sparse image.
    var diskImage: URL {
        directory.appendingPathComponent("Disk.img", isDirectory: false)
    }

    /// The UEFI variable store of the machine for a given architecture.
    ///
    /// - Parameter architecture: The architecture the firmware was built for.
    /// - Returns: The location of the variable store.
    func variableStore(for architecture: QEMUMachineOptions.Architecture) -> URL {
        directory.appendingPathComponent("QEMU-\(architecture.rawValue)-NVRAM", isDirectory: false)
    }

    /// Creates the machine directory if it does not exist yet.
    func prepareDirectory() throws {
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )

        } catch { throw VZKitError.qemuStorageFailedSetup(directory.lastPathComponent) }
    }

    /// Returns the UEFI firmware image for an architecture.
    ///
    /// - Parameters:
    ///   - architecture: The architecture of the guest.
    ///   - helper: The helper service bundle carrying the emulator's data files.
    /// - Returns: The location of the read-only firmware code.
    func firmwareCode(
        for architecture: QEMUMachineOptions.Architecture,
        in helper: QEMUHelperBundle
    ) throws -> URL {
        switch architecture {
        case .aarch64: return try helper.dataFile(named: "edk2-aarch64-code.fd")
        case .x86_64: return try helper.dataFile(named: "edk2-x86_64-code.fd")
        }
    }

    /// Returns the UEFI variable store for an architecture, creating it on first use.
    ///
    /// The store is what makes boot entries and firmware settings survive a power cycle. For ARM the
    /// firmware accepts, and formats, an erased flash device, so an empty sparse file of the right size
    /// is enough. For x86 the store has to be pre-formatted and is copied from the template that ships
    /// with the emulator.
    ///
    /// - Parameters:
    ///   - architecture: The architecture of the guest.
    ///   - helper: The helper service bundle carrying the emulator's data files.
    /// - Returns: The location of the writable variable store.
    func prepareVariableStore(
        for architecture: QEMUMachineOptions.Architecture,
        in helper: QEMUHelperBundle
    ) throws -> URL {

        let store = variableStore(for: architecture)

        guard !FileManager.default.fileExists(atPath: store.path(percentEncoded: false)) else {
            return store
        }

        switch architecture {
        case .aarch64:
            try Self.createSparseFile(at: store, size: Self.armFlashSize)

        case .x86_64:
            let template = try helper.dataFile(named: "edk2-i386-vars.fd")

            do {
                try FileManager.default.copyItem(at: template, to: store)

            } catch { throw VZKitError.qemuStorageFailedSetup(store.lastPathComponent) }
        }

        return store
    }

    /// Creates an empty file of a given logical size without allocating its blocks.
    ///
    /// Nothing is left behind when the file cannot be brought to its size: a truncated leftover would
    /// be mistaken for a provisioned file the next time around.
    ///
    /// - Parameters:
    ///   - url: The location of the new file. An existing file is left untouched.
    ///   - size: The logical size, in bytes.
    static func createSparseFile(at url: URL, size: UInt64) throws {

        let path = url.path(percentEncoded: false)

        guard !FileManager.default.fileExists(atPath: path) else { return }

        guard FileManager.default.createFile(atPath: path, contents: nil, attributes: nil) else {
            throw VZKitError.qemuStorageFailedSetup(url.lastPathComponent)
        }

        do {
            let fileHandle = try FileHandle(forWritingTo: url)
            defer { try? fileHandle.close() }

            try fileHandle.truncate(atOffset: size)

        } catch {
            try? FileManager.default.removeItem(at: url)

            throw VZKitError.qemuStorageFailedSetup(url.lastPathComponent)
        }
    }

    /// Resolves the layout of a machine.
    ///
    /// - Parameter machineID: The identifier of the template the machine is built from.
    init(machineID: UUID) async {
        self.directory = await VirtualizationKit.supportDirectory.appendingPathComponent(
            machineID.uuidString
        )
    }
}
