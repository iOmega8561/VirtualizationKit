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

    /// The access mode. It has to match the mode the emulator opens the corresponding drive with:
    /// the emulator picks a descriptor out of a set by comparing access modes.
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
        let descriptor = Self.firstBrokeredDescriptor + Int32(descriptors.count)
        let set = descriptors.count + 1

        descriptors.append(source)
        arguments.append(contentsOf: ["-add-fd", "fd=\(descriptor),set=\(set)"])

        return "/dev/fdset/\(set)"
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
