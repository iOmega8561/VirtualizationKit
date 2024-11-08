//
//  VZKitNetworkTopology.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 08/11/24.
//

/// `VZKitNetworkTopology` is a protocol that defines the various network topology modes
/// available for network virtualization within `VirtualizationKit`. This protocol allows configuring
/// the virtual network as "no connection," with a NAT interface, or with a bridged interface
/// on a specific host network interface.
///
/// By conforming to `CaseIterable`, `Codable`, `Hashable`, and `Sendable`, this protocol enables
/// enumeration, encoding, and secure transfer of network configurations in an identifiable manner.
public protocol VZKitNetworkTopology: CaseIterable, Codable, Hashable, Sendable {
    
    /// No network configured for the virtual machine.
    ///
    /// This setting disables network connectivity for the virtual machine.
    static var none: Self { get }
    
    /// Configures a NAT (Network Address Translation) network for the virtual machine.
    ///
    /// With NAT mode, the virtual machine can access external networks using the host's IP
    /// as a gateway, while remaining isolated from the local network. This option is useful
    /// for maintaining the privacy of the virtual machine, preventing interference with other
    /// devices on the same local network.
    static var nat: Self { get }
    
    /// Configures a bridged network with a specific host network interface.
    ///
    /// - Parameter hostInterfaceID: The identifier of the host network interface to use
    ///   for the bridged connection. This allows the virtual machine to appear as an
    ///   independent device on the same network as the host.
    ///
    /// Bridged mode enables the virtual machine to be visible on the local network as a
    /// separate device, useful for advanced configurations or when the virtual machine
    /// needs its own IP address to interact with other devices on the same network.
    static func bridged(_ hostInterfaceID: String) -> Self
}
