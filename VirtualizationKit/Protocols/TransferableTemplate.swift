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
    
    /// The operating system configuration associated with this template.
    ///
    /// Provides details about which OS is used in the VM, as well as any
    /// relevant configuration specific to that OS.
    var operatingSystem: OperatingSystem { get }
    
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
    
    /// A collection of optional capabilities to enable for the VM.
    ///
    /// These may include specialized hardware capabilities, security features, or
    /// experimental functionalities that can be toggled on for the VM.
    var optionalCapabilities: [OptionalCapability] { get }
}
