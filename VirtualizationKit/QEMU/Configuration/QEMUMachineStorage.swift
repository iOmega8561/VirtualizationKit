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

    /// The UEFI variable store of the machine for a given firmware.
    ///
    /// The Secure Boot firmware keeps its variables in a different layout, so it has a store of its own.
    ///
    /// - Parameters:
    ///   - architecture: The architecture the firmware was built for.
    ///   - secureBoot: Whether the firmware is the Secure Boot capable one.
    /// - Returns: The location of the variable store.
    func variableStore(for architecture: QEMUMachineOptions.Architecture, secureBoot: Bool) -> URL {
        let variant = secureBoot ? "-secure" : ""
        return directory.appendingPathComponent("QEMU-\(architecture.rawValue)\(variant)-NVRAM", isDirectory: false)
    }

    /// The state of the machine's software TPM: its keys, counters and other persistent data.
    var tpmState: URL {
        directory.appendingPathComponent("QEMU-TPM", isDirectory: false)
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
    ///   - secureBoot: Whether to return the Secure Boot capable build.
    ///   - helper: The helper service bundle carrying the emulator's data files.
    /// - Returns: The location of the read-only firmware code.
    func firmwareCode(
        for architecture: QEMUMachineOptions.Architecture,
        secureBoot: Bool,
        in helper: QEMUHelperBundle
    ) throws -> URL {
        switch (architecture, secureBoot) {
        case (.aarch64, false): return try helper.dataFile(named: "edk2-aarch64-code.fd")
        case (.aarch64, true): return try helper.dataFile(named: "edk2-aarch64-secure-code.fd")
        case (.x86_64, false): return try helper.dataFile(named: "edk2-x86_64-code.fd")
        case (.x86_64, true): return try helper.dataFile(named: "edk2-x86_64-secure-code.fd")
        }
    }

    /// Returns the UEFI variable store for a firmware, creating it on first use.
    ///
    /// The store is what makes boot entries and firmware settings survive a power cycle.
    ///
    /// - The standard ARM firmware accepts, and formats, an erased flash device, so an empty sparse file
    ///   of the right size is enough.
    /// - The Secure Boot capable ARM firmware needs a pre-formatted store. The template that ships with
    ///   the emulator is smaller than a flash device of the `virt` machine and is extended to its size.
    /// - For x86 the store is always pre-formatted and copied from the matching template.
    ///
    /// - Parameters:
    ///   - architecture: The architecture of the guest.
    ///   - secureBoot: Whether the store is for the Secure Boot capable firmware.
    ///   - helper: The helper service bundle carrying the emulator's data files.
    /// - Returns: The location of the writable variable store.
    func prepareVariableStore(
        for architecture: QEMUMachineOptions.Architecture,
        secureBoot: Bool,
        in helper: QEMUHelperBundle
    ) throws -> URL {

        let store = variableStore(for: architecture, secureBoot: secureBoot)

        guard !FileManager.default.fileExists(atPath: store.path(percentEncoded: false)) else {
            return store
        }

        switch (architecture, secureBoot) {
        case (.aarch64, false):
            try Self.createSparseFile(at: store, size: Self.armFlashSize)

        case (.aarch64, true):
            try Self.copy(try helper.dataFile(named: "edk2-arm-secure-vars.fd"), to: store, extendingTo: Self.armFlashSize)

        case (.x86_64, false):
            try Self.copy(try helper.dataFile(named: "edk2-i386-vars.fd"), to: store, extendingTo: nil)

        case (.x86_64, true):
            try Self.copy(try helper.dataFile(named: "edk2-i386-secure-vars.fd"), to: store, extendingTo: nil)
        }

        return store
    }

    /// Returns the state file of the machine's software TPM, creating it on first use.
    ///
    /// The file starts empty; the TPM formats it the first time it runs.
    ///
    /// - Returns: The location of the state file.
    func prepareTPMState() throws -> URL {

        let state = tpmState
        let path = state.path(percentEncoded: false)

        guard !FileManager.default.fileExists(atPath: path) else { return state }

        guard FileManager.default.createFile(atPath: path, contents: nil, attributes: nil) else {
            throw VZKitError.qemuStorageFailedSetup(state.lastPathComponent)
        }

        return state
    }

    /// Copies a template into place, optionally extending the copy to a given size.
    ///
    /// The copy is prepared under a temporary name and moved into place only once complete, so a failure
    /// never leaves a half-made store behind for the next start to pick up.
    ///
    /// - Parameters:
    ///   - template: The file to copy.
    ///   - destination: Where the copy goes. It must not exist yet.
    ///   - size: The size to extend the copy to, if any. Added space reads as zeros.
    private static func copy(_ template: URL, to destination: URL, extendingTo size: UInt64?) throws {

        let partial = destination.appendingPathExtension("partial")

        do {
            try? FileManager.default.removeItem(at: partial)
            try FileManager.default.copyItem(at: template, to: partial)

            if let size {
                let fileHandle = try FileHandle(forWritingTo: partial)
                defer { try? fileHandle.close() }

                if try fileHandle.seekToEnd() < size {
                    try fileHandle.truncate(atOffset: size)
                }
            }

            try FileManager.default.moveItem(at: partial, to: destination)

        } catch {
            try? FileManager.default.removeItem(at: partial)
            throw VZKitError.qemuStorageFailedSetup(destination.lastPathComponent)
        }
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
