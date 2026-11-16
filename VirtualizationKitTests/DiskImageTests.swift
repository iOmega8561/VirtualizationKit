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

@Suite("Disk images")
struct DiskImageTests {

    private func disk(_ bootOrder: Int?, id: UUID = UUID()) -> DiskImage {
        DiskImage(id: id, location: .managed(size: 4096), interface: .virtio, bootOrder: bootOrder)
    }

    @Test("Disks with a boot order come first, by order; the others keep their position")
    func bootSequence() {
        let a = disk(nil), b = disk(2), c = disk(0), e = disk(nil), f = disk(1)
        #expect(DiskImage.bootSequence(of: [a, b, c, e, f]).map(\.id) == [c.id, f.id, b.id, a.id, e.id])
        #expect(DiskImage.bootSequence(of: []).isEmpty)
    }

    @Test("Valid storage passes the shared rules")
    func validStorage() throws {
        try DiskImage.validate([disk(0), disk(1), disk(nil)])
        try DiskImage.validate([])
        let installer = DiskImage(location: .external(bookmark: Data()), kind: .optical, interface: .usb, bootOrder: 0)
        try DiskImage.validate([installer])
    }

    @Test("Each shared rule rejects the disk that breaks it")
    func invalidStorage() {
        let twice = disk(nil)
        #expect(throws: VZKitError.invalidDiskImage(twice.id)) { try DiskImage.validate([twice, twice]) }

        let first = disk(1), second = disk(1)
        #expect(throws: VZKitError.invalidDiskImage(second.id)) { try DiskImage.validate([first, second]) }

        let negative = disk(-1)
        #expect(throws: VZKitError.invalidDiskImage(negative.id)) { try DiskImage.validate([negative]) }

        let empty = DiskImage(location: .managed(size: 0), interface: .virtio)
        #expect(throws: VZKitError.invalidDiskImage(empty.id)) { try DiskImage.validate([empty]) }

        let managedOptical = DiskImage(location: .managed(size: 4096), kind: .optical, interface: .usb)
        #expect(throws: VZKitError.invalidDiskImage(managedOptical.id)) { try DiskImage.validate([managedOptical]) }

        let writableOptical = DiskImage(location: .external(bookmark: Data()), kind: .optical, interface: .usb, isReadOnly: false)
        #expect(throws: VZKitError.invalidDiskImage(writableOptical.id)) { try DiskImage.validate([writableOptical]) }
    }

    @Test("Optical discs default to read-only, hard disks to writable")
    func readOnlyDefaults() {
        #expect(DiskImage(location: .external(bookmark: Data()), kind: .optical, interface: .usb).isReadOnly)
        #expect(!disk(nil).isReadOnly)
    }

    @Test("Disk images survive encoding")
    func coding() throws {
        let disks = [
            DiskImage(location: .external(bookmark: Data([1, 2, 3])), kind: .optical, interface: .usb, bootOrder: 3),
            DiskImage(location: .managed(size: 1 << 30), interface: .nvme)
        ]
        let decoded = try JSONDecoder().decode([DiskImage].self, from: JSONEncoder().encode(disks))
        #expect(decoded == disks)
    }

    @Test("A managed disk is created once, sparse, at its size, and named after its identifier")
    func managedDisk() throws {
        let directory = try TemporaryDirectory()
        let store = DiskImageStore(directory: directory.url)
        let image = DiskImage(location: .managed(size: 1 << 20), interface: .virtio)

        let provisioned = try store.provision(image)
        #expect(provisioned.url.lastPathComponent == "Disk-\(image.id.uuidString).img")
        #expect(provisioned.access == nil)
        let size = try FileManager.default.attributesOfItem(atPath: provisioned.url.path)[.size] as? UInt64
        #expect(size == 1 << 20)

        // A later, larger size does not touch the existing file.
        var larger = image
        larger.location = .managed(size: 1 << 21)
        _ = try store.provision(larger)
        let unchanged = try FileManager.default.attributesOfItem(atPath: provisioned.url.path)[.size] as? UInt64
        #expect(unchanged == 1 << 20)
    }

    @Test("An external disk is resolved from its bookmark, or reported as unreachable")
    func externalDisk() throws {
        let directory = try TemporaryDirectory()
        let store = DiskImageStore(directory: directory.url)
        let file = directory.file("data.img", size: 512)

        let found = try store.provision(DiskImage(location: .external(bookmark: try bookmark(to: file)), interface: .usb))
        // On macOS the temporary directory is reached through a symlink; compare where the paths lead.
        #expect(found.url.resolvingSymlinksInPath().path == file.resolvingSymlinksInPath().path)
        #expect(found.access != nil)

        let gone = directory.file("gone.img")
        let staleBookmark = try bookmark(to: gone)
        try FileManager.default.removeItem(at: gone)
        #expect(throws: VZKitError.self) {
            try store.provision(DiskImage(location: .external(bookmark: staleBookmark), interface: .usb))
        }

        #expect(throws: VZKitError.diskImageUnreachable(nil)) {
            try store.provision(DiskImage(location: .external(bookmark: Data([0xFF])), interface: .usb))
        }
    }
}
