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

import Virtualization

extension VZStorageDeviceConfiguration {

    /// This is the static factory method for `VZStorageDeviceConfiguration`. It attaches the file of a
    /// disk through the interface the disk asks for.
    ///
    /// Virtualization.framework has no optical drive: an optical disc is attached as a read-only disk,
    /// which firmware and installers boot from just the same.
    ///
    /// - Note: This is deliberately not a `SpecializedConstructible` conformance. A subclass, the USB
    ///   mass storage device, already conforms to `PersistentConstructible` for hot-plugged media, and
    ///   the two protocols would disagree on its `InputType`.
    ///
    /// - Parameter disk: A disk of the template together with the location of its file.
    /// - Returns: The storage device presenting the disk to the guest.
    /// - Throws: `VZKitError.diskImageFailedSetup` if the file cannot be attached.
    static func create(for disk: ProvisionedDiskImage) throws -> VZStorageDeviceConfiguration {

        let attachment: VZDiskImageStorageDeviceAttachment

        do {
            attachment = try VZDiskImageStorageDeviceAttachment(
                url: disk.url,
                readOnly: disk.image.isReadOnly
            )
        } catch {
            VZKitLogger.default.error(
                "Disk \(disk.image.id.uuidString) cannot be attached: \(error.localizedDescription)"
            )
            throw VZKitError.diskImageFailedSetup
        }

        return switch disk.image.interface {
        case .virtio: VZVirtioBlockDeviceConfiguration(attachment: attachment)
        case .nvme: VZNVMExpressControllerDeviceConfiguration(attachment: attachment)
        case .usb: VZUSBMassStorageDeviceConfiguration(attachment: attachment)
        }
    }
}
