//
//  VZKitTemplate.swift
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
/// Conforming to both `Identifiable` and `VZKitTransferable`, each template can be uniquely
/// identified and easily transferred or serialized within the framework.
public protocol VZKitTemplate: Identifiable, VZKitTransferable {
    
    /// A unique identifier for the template.
    ///
    /// Use this ID to differentiate one template from another, especially when
    /// managing or storing multiple templates in a collection or database.
    var id: UUID { get }
    
    /// A descriptive, human-readable name for the template.
    ///
    /// Use this property to label or display the template in the user interface.
    var name: String { get }
    
    /// The operating system configuration associated with this template.
    ///
    /// Provides details about which OS is used in the VM, as well as any
    /// relevant configuration specific to that OS.
    var operatingSystem: OperatingSystem { get }
    
    /// An optional URL pointing to a removable install media, such as a CD-ROM image.
    ///
    /// If provided, the Virtual Machine can boot or install from the given image. If `nil`,
    /// the VM may rely on other sources for installation media.
    var removableInstallMedia: URL? { get }
    
    /// The network configuration defining how the VM connects to other networks or VMs.
    ///
    /// This property encapsulates details such as NIC types, NAT or bridged networking,
    /// and other connectivity parameters for the VM.
    var networkTopology: NetworkTopology { get }
    
    /// A preset describing the desired hardware resources and performance level.
    ///
    /// This property indicates how many CPU cores, how much memory, and other performance
    /// aspects are allocated to the VM.
    var performancePreset: PerformancePreset { get }
    
    /// A collection of optional features to enable for the VM.
    ///
    /// These may include specialized hardware capabilities, security features, or
    /// experimental functionalities that can be toggled on for the VM.
    var featuresToEnable: [OptionalFeature] { get }
}
