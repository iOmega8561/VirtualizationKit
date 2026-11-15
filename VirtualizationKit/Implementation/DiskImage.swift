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

/// A disk of a virtual machine.
///
/// A disk image answers three separate questions:
///
/// - **Where the file lives** (`location`): inside the directory of the machine, created and owned by
///   the framework, or anywhere else on the host, picked by the user.
/// - **What the guest sees** (`kind`, `interface`, `isReadOnly`): a hard disk or an optical disc, and the
///   bus it is attached to.
/// - **Whether the firmware boots from it** (`bootOrder`).
///
/// Nothing here is inferred from the guest operating system. The interface in particular is always
/// stated: which one a guest can boot from depends on the drivers it ships with, and a value that is
/// chosen once and persisted keeps describing the same hardware in every later release.
///
/// ```swift
/// let system = DiskImage(
///     location: .managed(size: 64 * 1024 * 1024 * 1024),
///     interface: .virtio,
///     bootOrder: 1
/// )
///
/// let installer = DiskImage(
///     location: try .external(fileAt: isoURL, readOnly: true),
///     kind: .optical,
///     interface: .usb,
///     bootOrder: 0
/// )
/// ```
public struct DiskImage: Transferable, Identifiable {

    // MARK: - Supporting Types

    /// Where the file backing a disk lives.
    public enum Location: Transferable {

        /// A file inside the directory of the virtual machine.
        ///
        /// The framework creates it, as a sparse file of the given size, the first time the machine is
        /// built, and names it after the identifier of the disk. The size is a creation-time property:
        /// changing it later has no effect on a file that already exists.
        ///
        /// - Parameter size: The capacity of the disk, in bytes.
        case managed(size: UInt64)

        /// A file anywhere on the host, typically one the user picked.
        ///
        /// The file is referred to by a bookmark rather than by a URL. A URL loses its security scope
        /// when it is encoded, so a template that stored one could not reach the file after the
        /// application is relaunched inside the App Sandbox. The framework resolves the bookmark and
        /// keeps the file reachable for as long as the virtual machine exists.
        ///
        /// - Parameter bookmark: Bookmark data for the file; see `external(fileAt:readOnly:)`.
        case external(bookmark: Data)
    }

    /// What a disk is to the guest.
    public enum Kind: String, Transferable, CaseIterable {

        /// A hard disk.
        case disk

        /// An optical disc, such as the ISO image of an installer. Always read-only.
        ///
        /// Backends that can present an optical drive do so; the others attach the image as a
        /// read-only disk, which is how installers written to USB sticks are booted.
        case optical

        /// A localized, human-readable name for the kind.
        public var localizedName: String {
            switch self {
            case .disk: VZKitLocale("diskkind-disk").value
            case .optical: VZKitLocale("diskkind-optical").value
            }
        }
    }

    /// The bus a disk is attached to.
    ///
    /// - Note: Not every backend offers every interface for every kind of disk. A combination the
    ///   backend cannot provide is rejected when the virtual machine is validated.
    public enum Interface: String, Transferable, CaseIterable {

        /// A paravirtualized block device. The fastest option, for guests with a virtio driver.
        case virtio

        /// An NVMe controller, for guests that ship an NVMe driver but no virtio one.
        case nvme

        /// A USB mass storage device.
        case usb

        /// The name the interface is commonly known by. Not localized.
        public var displayName: String {
            switch self {
            case .virtio: "virtio"
            case .nvme: "NVMe"
            case .usb: "USB"
            }
        }
    }

    /// The on-disk format of an image.
    public enum Format: String, Transferable, CaseIterable {

        /// The bytes of the disk, one after the other.
        case raw
    }

    // MARK: - Properties

    /// The identity of the disk.
    ///
    /// It names the file of a managed disk and identifies the device to the guest where the interface
    /// has a notion of a serial number, so it has to stay the same for the lifetime of the disk.
    public var id: UUID

    /// Where the file backing the disk lives.
    public var location: Location

    /// What the disk is to the guest.
    public var kind: Kind

    /// The bus the disk is attached to.
    public var interface: Interface

    /// The on-disk format of the image.
    public var format: Format

    /// Whether the guest is kept from writing to the disk.
    public var isReadOnly: Bool

    /// The position of the disk in the boot sequence of the firmware, or `nil` to never boot from it.
    ///
    /// Lower values come first, and no two disks of a machine may share one.
    ///
    /// - Note: The QEMU backend passes the order to the firmware. Virtualization.framework has no such
    ///   setting; the Apple backend presents the disks in this order, which is the best it can do.
    public var bootOrder: Int?

    // MARK: - Initializers

    /// Creates a disk.
    ///
    /// - Parameters:
    ///   - id: The identity of the disk. Defaults to a new one.
    ///   - location: Where the file backing the disk lives.
    ///   - kind: What the disk is to the guest. Defaults to a hard disk.
    ///   - interface: The bus the disk is attached to.
    ///   - format: The on-disk format of the image. Defaults to `raw`.
    ///   - isReadOnly: Whether the guest is kept from writing to the disk. When omitted, optical discs
    ///     are read-only and hard disks are writable.
    ///   - bootOrder: The position in the boot sequence, or `nil` to never boot from the disk.
    public init(
        id: UUID = UUID(),
        location: Location,
        kind: Kind = .disk,
        interface: Interface,
        format: Format = .raw,
        isReadOnly: Bool? = nil,
        bootOrder: Int? = nil
    ) {
        self.id = id
        self.location = location
        self.kind = kind
        self.interface = interface
        self.format = format
        self.isReadOnly = isReadOnly ?? (kind == .optical)
        self.bootOrder = bootOrder
    }
}

public extension DiskImage.Location {

    /// Refers to a file anywhere on the host by creating a security-scoped bookmark for it.
    ///
    /// Call this while the file is reachable, i.e. with the URL an open panel or a drop just returned.
    /// The resulting value can be persisted with the template and keeps working across launches.
    ///
    /// - Parameters:
    ///   - url: The location of the file.
    ///   - readOnly: Whether read access is all the bookmark should grant. Use it for images the guest
    ///     never writes to, such as installers.
    /// - Returns: An `external` location carrying the bookmark.
    /// - Throws: A localized error if no bookmark can be created, typically because the file is missing.
    static func external(fileAt url: URL, readOnly: Bool = false) throws -> Self {
        var options: URL.BookmarkCreationOptions = [.withSecurityScope]
        if readOnly { options.insert(.securityScopeAllowOnlyReadAccess) }

        do {
            return .external(bookmark: try url.bookmarkData(options: options))
        } catch {
            VZKitLogger.default.error("No bookmark for \(url.lastPathComponent): \(error.localizedDescription)")
            throw VZKitError.diskImageUnreachable(url.lastPathComponent)
        }
    }
}

// MARK: - Storage Rules

extension DiskImage {

    /// The file name of a managed disk inside the directory of its virtual machine.
    var managedFileName: String { "Disk-\(id.uuidString).img" }

    /// The disks of a machine in the order the firmware should try them.
    ///
    /// Disks with a boot order come first, by ascending order; the others follow in the order they
    /// were declared in.
    ///
    /// - Parameter storage: The disks of a template.
    /// - Returns: The same disks, reordered.
    static func bootSequence(of storage: [DiskImage]) -> [DiskImage] {
        storage.enumerated().sorted { lhs, rhs in
            switch (lhs.element.bootOrder, rhs.element.bootOrder) {
            case let (left?, right?) where left != right: left < right
            case (.some, nil): true
            case (nil, .some): false
            default: lhs.offset < rhs.offset
            }
        }.map(\.element)
    }

    /// Checks the rules every backend shares, without touching the file system.
    ///
    /// - Each disk has an identifier of its own.
    /// - A managed disk is a hard disk with a capacity.
    /// - An optical disc is read-only.
    /// - Boot orders are not negative and not shared.
    ///
    /// - Parameter storage: The disks of a template.
    /// - Throws: `VZKitError.invalidDiskImage` for the first disk that breaks a rule.
    static func validate(_ storage: [DiskImage]) throws {
        var identifiers: Set<UUID> = []
        var bootOrders: Set<Int> = []

        for disk in storage {
            guard identifiers.insert(disk.id).inserted else {
                throw invalid(disk, "its identifier is used by another disk")
            }

            if case .managed(let size) = disk.location {
                guard disk.kind == .disk else { throw invalid(disk, "a managed image cannot be an optical disc") }
                guard size > 0 else { throw invalid(disk, "a managed image needs a capacity") }
            }

            if disk.kind == .optical, !disk.isReadOnly {
                throw invalid(disk, "an optical disc cannot be writable")
            }

            if let bootOrder = disk.bootOrder {
                guard bootOrder >= 0 else { throw invalid(disk, "its boot order is negative") }
                guard bootOrders.insert(bootOrder).inserted else {
                    throw invalid(disk, "its boot order is used by another disk")
                }
            }
        }
    }

    /// Logs why a disk is rejected and returns the error to throw for it.
    private static func invalid(_ disk: DiskImage, _ reason: String) -> VZKitError {
        VZKitLogger.default.error("Disk \(disk.id.uuidString) is not valid: \(reason)")
        return .invalidDiskImage(disk.id)
    }
}
