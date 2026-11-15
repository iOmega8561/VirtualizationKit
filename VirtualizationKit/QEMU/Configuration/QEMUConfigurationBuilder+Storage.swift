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

extension QEMUConfigurationBuilder {

    /// Emits the disks of the template.
    ///
    /// Every disk becomes a block backend (`-drive`) and a device that presents it to the guest. The
    /// device depends on the interface the disk asks for and nothing else:
    ///
    /// - `virtio`: a paravirtualized block device.
    /// - `nvme`: an NVMe controller. It needs a serial number of at most 20 characters; the identifier
    ///   of the disk provides a stable one.
    /// - `usb`: a mass storage device on the controller emitted with the core devices. An optical disc
    ///   is presented as a removable CD-ROM drive.
    ///
    /// A managed disk is a raw, sparse image created on first use. An external one is resolved from its
    /// bookmark. A disk with a boot order is announced to the firmware at that position; the others are
    /// left out of the boot sequence.
    ///
    /// All files are brokered: writable ones read-write (which also hands over a read-only descriptor,
    /// see `QEMULaunchPlan.broker(_:)`), the others read-only.
    ///
    /// - Note: The USB devices reference the controller emitted with the core devices, so this has to
    ///   run after them.
    ///
    /// - Returns: The guards keeping the external images reachable, to be held for as long as the plan
    ///   is in use.
    func appendStorage(to plan: inout QEMULaunchPlan) throws -> [SecurityScopedAccess] {

        let disks = try storage.disks.provision(template.storage)

        for (index, disk) in disks.enumerated() {

            let image = disk.image
            let drive = "disk\(index)"

            let file = plan.broker(.init(
                url: disk.url,
                access: image.isReadOnly ? .readOnly : .readWrite
            ))

            var backend = ["if=none", "id=\(drive)"]

            if image.kind == .optical { backend.append("media=cdrom") }

            switch image.format {
            case .raw: backend.append("format=raw")
            }

            // Discarded blocks are given back to the host, which keeps a sparse image sparse.
            backend.append(image.isReadOnly ? "readonly=on" : "discard=unmap")
            backend.append("file=\(file)")

            var device: [String]

            switch image.interface {
            case .virtio:
                device = ["virtio-blk-pci", "drive=\(drive)"]

            case .nvme:
                let serial = image.id.uuidString.replacingOccurrences(of: "-", with: "").prefix(20)
                device = ["nvme", "drive=\(drive)", "serial=\(serial)"]

            case .usb:
                device = ["usb-storage", "drive=\(drive)"]
                if image.kind == .optical { device.append("removable=on") }
                device.append("bus=xhci.0")
            }

            if let bootOrder = image.bootOrder { device.append("bootindex=\(bootOrder)") }

            plan.append("-drive", backend.joined(separator: ","))
            plan.append("-device", device.joined(separator: ","))
        }

        return disks.compactMap(\.access)
    }
}
