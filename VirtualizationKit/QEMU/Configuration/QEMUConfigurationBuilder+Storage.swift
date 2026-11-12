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

    /// Emits the main disk and, when the template has one, the install media.
    ///
    /// The main disk is a raw, sparse image created on first use at the size of the template's
    /// performance preset. It has the same name and location as the disk of the Apple backend.
    ///
    /// The install media is attached as a removable USB drive that boots before the disk, so a fresh
    /// machine starts the installer and an installed one keeps booting from its disk once the media
    /// is removed from the template.
    ///
    /// Both files are brokered: the disk read-write (which also hands over a read-only descriptor, see
    /// `QEMULaunchPlan.broker(_:)`), the media read-only.
    ///
    /// - Note: The USB devices reference the controller emitted with the core devices, so this has to
    ///   run after them.
    func appendStorage(to plan: inout QEMULaunchPlan) throws {

        try QEMUMachineStorage.createSparseFile(
            at: storage.diskImage,
            size: template.performancePreset.diskSize
        )

        let disk = plan.broker(.init(url: storage.diskImage, access: .readWrite))

        plan.append("-drive", "if=none,id=disk0,format=raw,discard=unmap,file=\(disk)")
        plan.append("-device", "virtio-blk-pci,drive=disk0,bootindex=1")

        guard let media = template.bootableInstallMedia else { return }

        let installMedia = plan.broker(.init(url: media, access: .readOnly))

        plan.append("-drive", "if=none,id=cd0,media=cdrom,format=raw,readonly=on,file=\(installMedia)")
        plan.append("-device", "usb-storage,drive=cd0,removable=on,bus=xhci.0,bootindex=0")
    }
}
