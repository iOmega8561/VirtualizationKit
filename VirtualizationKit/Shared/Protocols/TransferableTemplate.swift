//
//  Copyright 2025 Giuseppe Rocco
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
//  -----------------------------------------------------------------------
//
//  TransferableTemplate.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 12/10/24.
//

import Foundation

/// A protocol defining a minimal, streamlined configuration for creating VMs within the VZKit framework.
///
/// Conforming types include just enough information to configure and launch a virtual machine,
/// without embedding the complete Virtualization Framework data. This enables simpler, more
/// flexible setups for defining new VMs in your application.
///
/// Conforming to both `Identifiable` and `Transferable`, each template can be uniquely
/// identified and easily transferred or serialized within the framework.
public protocol TransferableTemplate: Identifiable, Transferable {
    
    /// A unique identifier for the template.
    ///
    /// Use this ID to differentiate one template from another, especially when
    /// managing or storing multiple templates in a collection or database.
    var id: UUID { get }
    
    /// A descriptive, human-readable name for the template.
    ///
    /// Use this property to label or display the template in the user interface.
    var name: String { get }
    
    /// The disks attached to the VM when it starts.
    ///
    /// Each element describes one disk: a hard disk the framework creates and keeps inside the
    /// directory of the machine, or an image picked by the user, such as the ISO of an installer.
    /// A machine can have any number of them, including none.
    ///
    /// The identifier of a disk has to be unique within the template, and so does its boot order
    /// when it has one. See `DiskImage` for the meaning of the individual properties.
    var storage: [DiskImage] { get }
    
    /// The network configuration defining how the VM connects to other networks or VMs.
    ///
    /// This property encapsulates details such as NIC types, NAT or bridged networking,
    /// and other connectivity parameters for the VM.
    var networkTopology: NetworkTopology { get }
    
    /// A preset describing the desired hardware resources and performance level.
    ///
    /// This property indicates how many CPU cores and how much memory are allocated to the VM.
    /// It is resolved against the capabilities of the host every time the VM is built.
    var performancePreset: PerformancePreset { get }
    
    /// The size of the guest display when the VM is powered on.
    ///
    /// The guest can change its resolution afterwards; see `DisplaySize`.
    var display: DisplaySize { get }

    /// A collection of optional capabilities to enable for the VM.
    ///
    /// These may include specialized hardware capabilities, security features, or
    /// experimental functionalities that can be toggled on for the VM.
    var optionalCapabilities: [OptionalCapability] { get }
}

// MARK: - Machine Files

public extension TransferableTemplate {

    /// Deletes the files the machine of this template has on disk.
    ///
    /// Call it when the user deletes a virtual machine. Nothing happens if the machine has no files yet.
    ///
    /// ```swift
    /// try await template.deleteMachineFiles()
    /// ```
    ///
    /// - Important: This includes the folder an Apple machine shares with the guest, and whatever the guest
    ///   put there. Disk images outside the directory of the machine, such as installers or disks the user
    ///   picked, are kept.
    ///
    /// - Throws: `VZKitError.machineInUse` if a machine created from this template exists, here or in another
    ///   application; the error of the file system if a file cannot be removed.
    func deleteMachineFiles() async throws {
        let directory = await VirtualizationKit.machineDirectory(for: self)

        guard FileManager.default.fileExists(atPath: directory.path(percentEncoded: false)) else { return }

        let lock = try MachineLock(directory: directory)

        try withExtendedLifetime(lock) {
            try FileManager.default.removeItem(at: directory)
        }
    }

    /// Waits until no machine created from this template is in use, here or in another application.
    ///
    /// A machine holds the files of its template for as long as it exists: until the last copy of it is
    /// released, or its process ends. Creating another machine from the same template meanwhile fails with
    /// `VZKitError.machineInUse`. This waits for that moment instead, checking about every 100 milliseconds.
    ///
    /// ```swift
    /// try await template.waitForMachineRelease(timeout: .seconds(10))
    /// let machine = try await AppleVirtualMachine(template: template)
    /// ```
    ///
    /// - Note: Another application could still create a machine from the template between this method
    ///   returning and your next step. Within one application, that cannot happen unnoticed.
    ///
    /// - Parameter timeout: How long to wait at most, or `nil` to wait until the machine is released or the
    ///   task is cancelled.
    /// - Throws: `VZKitError.machineInUse` if the machine is still in use when the time is up;
    ///   `CancellationError` if the task is cancelled while waiting.
    func waitForMachineRelease(timeout: Duration? = nil) async throws {
        let directory = await VirtualizationKit.machineDirectory(for: self)
        let clock = ContinuousClock()
        let deadline = timeout.map { clock.now.advanced(by: $0) }

        while true {
            // A machine that has no files yet is not in use.
            guard FileManager.default.fileExists(atPath: directory.path(percentEncoded: false)) else { return }

            do {
                // Taken and released at once: only whether it can be taken matters.
                _ = try MachineLock(directory: directory)
                return
            } catch VZKitError.machineInUse {
                var pause = Duration.milliseconds(100)

                if let deadline {
                    let remaining = clock.now.duration(to: deadline)
                    guard remaining > .zero else { throw VZKitError.machineInUse }
                    pause = min(pause, remaining)
                }

                try await Task.sleep(for: pause)
            }
        }
    }
}
