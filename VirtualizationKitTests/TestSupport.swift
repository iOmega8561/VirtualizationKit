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
import Testing
@testable import VirtualizationKit

/// A template with nothing in it but what a test sets.
struct TestTemplate: TransferableTemplate {
    var id = UUID()
    var name = "Test"
    var storage: [DiskImage] = []
    var networkTopology: NetworkTopology = .none
    var performancePreset: PerformancePreset = .basic
    var display = DisplaySize(width: 1280, height: 720)
    var optionalCapabilities: [OptionalCapability] = []
}

/// A directory of its own for one test, removed when the value goes away.
final class TemporaryDirectory {

    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("VirtualizationKitTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    /// Creates an empty file in the directory.
    func file(_ name: String, size: Int = 0) -> URL {
        let file = url.appendingPathComponent(name, isDirectory: false)
        FileManager.default.createFile(atPath: file.path, contents: Data(count: size))
        return file
    }

    func exists(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: url.appendingPathComponent(name).path)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }
}

/// A bookmark to a file. Security-scoped bookmarks need the App Sandbox to be meaningful; the framework
/// resolves plain ones as well, which is what tests outside of the sandbox use.
func bookmark(to url: URL) throws -> Data {
    try url.bookmarkData()
}

/// Waits for a condition that is met asynchronously, such as a state delivered on the main queue.
@MainActor
func waitUntil(timeout: Duration = .seconds(2), _ condition: @MainActor () -> Bool) async throws {
    let deadline = ContinuousClock.now + timeout
    while !condition() {
        guard ContinuousClock.now < deadline else {
            Issue.record("Condition not met within \(timeout)")
            return
        }
        try await Task.sleep(for: .milliseconds(10))
    }
}

/// A helper service bundle with the layout of the real one and empty files in it, for building QEMU launch
/// plans without the emulator.
struct FakeHelperBundle {

    let bundle: QEMUHelperBundle
    let url: URL

    init(in directory: TemporaryDirectory, includesTPM: Bool = true) throws {
        let url = directory.url.appendingPathComponent("QEMUHelper.xpc", isDirectory: true)
        let fm = FileManager.default

        for folder in ["Contents/Frameworks", "Contents/MacOS", "Contents/Resources/qemu"] {
            try fm.createDirectory(at: url.appendingPathComponent(folder), withIntermediateDirectories: true)
        }
        for library in ["libqemu-aarch64-softmmu.dylib", "libqemu-x86_64-softmmu.dylib"] {
            fm.createFile(atPath: url.appendingPathComponent("Contents/Frameworks/\(library)").path, contents: Data())
        }
        if includesTPM {
            fm.createFile(
                atPath: url.appendingPathComponent("Contents/MacOS/QEMUTPM").path,
                contents: Data(),
                attributes: [.posixPermissions: 0o755]
            )
        }
        for firmware in ["edk2-aarch64-code.fd", "edk2-aarch64-secure-code.fd", "edk2-x86_64-code.fd",
                         "edk2-x86_64-secure-code.fd", "edk2-arm-secure-vars.fd", "edk2-i386-vars.fd",
                         "edk2-i386-secure-vars.fd"] {
            fm.createFile(atPath: url.appendingPathComponent("Contents/Resources/qemu/\(firmware)").path, contents: Data([1, 2, 3]))
        }

        self.url = url
        self.bundle = QEMUHelperBundle(url: url, serviceName: "VirtualizationKitTests")
    }
}
