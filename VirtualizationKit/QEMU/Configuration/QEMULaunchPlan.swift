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

/// A file the emulator needs, described by where it is and how it will be opened.
///
/// The emulator process never opens a path on its own. Each file is opened here, by the process that
/// holds the sandbox rights to it, and the open descriptor is handed over. A descriptor source is the
/// recipe for one such descriptor.
struct QEMUDescriptorSource: Sendable, Hashable {

    /// How the file is opened.
    enum Access: Sendable, Hashable {
        case readOnly
        case readWrite
    }

    /// The location of the file.
    let url: URL

    /// The access mode. The emulator picks a descriptor out of a set by comparing access modes, so
    /// it has to match the mode the emulator opens the file with. See `QEMULaunchPlan.broker(_:)`.
    let access: Access
}

/// Everything required to launch one emulator process.
///
/// A plan is a pure value: it can be built, inspected and compared without touching the helper
/// service. It contains no host paths. Files are referenced through descriptor sets instead, and the
/// order of `descriptors` defines the numbering used inside `arguments`.
struct QEMULaunchPlan: Sendable, Hashable {

    /// The number the control channel has inside the emulator process.
    static let controlDescriptor: Int32 = 3

    /// The number of the first brokered file inside the emulator process.
    ///
    /// The helper service places the staged descriptors at consecutive numbers starting here,
    /// in the order they were staged.
    static let firstBrokeredDescriptor: Int32 = 4

    /// The number the control channel of the software TPM has inside the emulator process.
    ///
    /// The launcher creates that channel itself, when asked to start a TPM, and places the emulator's
    /// end at this number: above every brokered descriptor, so the two can never collide.
    static let tpmControlDescriptor: Int32 = 100

    /// The launcher option that starts the software TPM. It is consumed by the launcher and never
    /// reaches the emulator. Its value is the descriptor of the TPM's state file.
    static let launcherTPMOption = "-launcher-tpm"

    /// The most descriptors a single launch may broker. The helper service enforces the same limit.
    static let maximumBrokeredDescriptors = 32

    /// The name of the system emulator library, without prefix and extension.
    let libraryName: String

    /// The command line of the emulator, without the program name.
    private(set) var arguments: [String] = []

    /// The files to open and hand over, in descriptor order.
    private(set) var descriptors: [QEMUDescriptorSource] = []

    /// Creates an empty plan for an emulator library.
    ///
    /// - Parameter libraryName: The name of the system emulator library.
    init(libraryName: String) {
        self.libraryName = libraryName
    }

    /// Appends raw command line arguments.
    ///
    /// - Parameter newArguments: The arguments, one element per `argv` entry.
    mutating func append(_ newArguments: String...) {
        arguments.append(contentsOf: newArguments)
    }

    /// Registers a file and returns the path under which the emulator can open it.
    ///
    /// The file is announced on the command line as a descriptor set of its own. The returned path
    /// refers to that set and is safe to embed in an option string as is.
    ///
    /// - Parameter source: The file to broker.
    /// - Returns: A `/dev/fdset/…` path naming the brokered file.
    mutating func broker(_ source: QEMUDescriptorSource) -> String {

        nextSet += 1
        let set = nextSet

        add(source, to: set)

        // The emulator does not open a writable image read-write right away. The block layer opens
        // it with the permissions it holds at that moment, which are read-only until the device
        // claims write access, and reopens it later. Each open picks a descriptor of the matching
        // mode out of the set, so a writable file needs a read-only descriptor next to its
        // read-write one; with the read-write one alone the first open fails.
        if source.access == .readWrite {
            add(.init(url: source.url, access: .readOnly), to: set)
        }

        return "/dev/fdset/\(set)"
    }

    /// The number of the last descriptor set handed out by `broker(_:)`.
    private var nextSet = 0

    /// Registers a file that is handed over as a plain descriptor, outside of any descriptor set.
    ///
    /// The emulator does not see such a file through `/dev/fdset`; it is meant for something else in its
    /// process, such as the launcher, which passes it on to the software TPM.
    ///
    /// - Parameter source: The file to hand over.
    /// - Returns: The number the descriptor has inside the emulator process.
    mutating func stage(_ source: QEMUDescriptorSource) -> Int32 {
        let descriptor = Self.firstBrokeredDescriptor + Int32(descriptors.count)
        descriptors.append(source)
        return descriptor
    }

    /// Registers one descriptor as a member of a descriptor set.
    private mutating func add(_ source: QEMUDescriptorSource, to set: Int) {
        let descriptor = Self.firstBrokeredDescriptor + Int32(descriptors.count)

        descriptors.append(source)
        arguments.append(contentsOf: ["-add-fd", "fd=\(descriptor),set=\(set)"])
    }

    /// Escapes a free-form value for use inside a comma-separated option string.
    ///
    /// The emulator splits option strings on commas; a literal comma is written twice.
    ///
    /// - Parameter value: The value to embed.
    /// - Returns: The escaped value.
    static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: ",", with: ",,")
    }
}
