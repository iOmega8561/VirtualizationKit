//
//  NetworkTopology.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 08/11/24.
//

import Virtualization

/// Represents the available network configurations for virtual machines in VirtualizationKit.
///
/// `NetworkTopology` defines the network connectivity options for a virtual machine,
/// including no connectivity, NAT (Network Address Translation), or bridged mode.
///
/// ### Key Features
/// - **Network Interfaces**: Provides a static property to retrieve available bridged network interfaces.
/// - **Random MAC Address Generation**: Offers a static property to generate a random, locally administered MAC address.
/// - **MAC Address Validation**: Includes a helper method to validate MAC address strings.
///
/// ### Enum Cases
/// - `none`: No network connectivity is configured.
/// - `nat(macAddress:)`: Provides NAT-based connectivity using the host’s IP address, with an assigned MAC address.
/// - `bridged(hostInterfaceID:macAddress:)`: Connects the virtual machine directly to a specified host network interface,
///   with an assigned MAC address.
///
/// ### Example Usage
/// ```swift
/// let topology: NetworkTopology = .bridged(hostInterfaceID: "en0")
/// print("Network configuration: \(topology.localizedName)")  // Outputs localized name
/// print("MAC Address: \(topology.macAddress ?? "N/A")")    // Outputs assigned MAC address
/// print("Interface: \(topology.hostInterfaceID ?? "Automatic")") // Outputs the host interface identifier or nil
/// ```
///
/// `NetworkTopology` conforms to `Transferable` for seamless integration within VirtualizationKit.
public enum NetworkTopology: Transferable {
    
    // MARK: - Static properties
    
    /// A static property that retrieves the list of network interface identifiers available for bridging.
    ///
    /// This property uses the `VZBridgedNetworkInterface` class to access all available network interfaces
    /// on the host machine. It maps each interface to its unique identifier string.
    ///
    /// - Returns: An array of `(String, String?)` where the left value is the identifier of the network interface, and the right
    /// value is a localized string representing the display name of the network interface (Wi-Fi or Ethernet, for example).
    /// If a localized name is not available, the right value is simply set to `nil`.
    public static var networkInterfaces: [(id: String, localizedName: String?)] {
        VZBridgedNetworkInterface.networkInterfaces.map {
            (id: $0.identifier, localizedName: $0.localizedDisplayName)
        }
    }
    
    /// A static property that generates a random MAC address suitable for locally administered use.
    ///
    /// This property utilizes the `VZMACAddress` class to create a random MAC address marked as
    /// locally administered. The address is then converted to its string representation.
    ///
    /// - Returns: A `String` representing the random, locally administered MAC address.
    public static var randomMacAddress: String {
        VZMACAddress.randomLocallyAdministered().string
    }
    
    // MARK: - Enum cases
    
    /// No network interface for the virtual machine.
    ///
    /// When this case is selected, the virtual machine will not be assigned any network
    /// connectivity, effectively isolating it from both the host and external networks.
    case none
    
    /// A NAT (Network Address Translation) network interface for the virtual machine.
    ///
    /// This case provides the virtual machine with network access via the host’s IP address,
    /// while isolating it from the rest of the host's local network. This is typically used to
    /// allow external network access without exposing the virtual machine to other devices on the same network.
    ///
    ///
    /// - Parameter macAddress: The machine hardware address to assign to the VM.
    ///   If not set this falls back to a default, random, value and is considered to be automatically managed by the framerowk.
    case nat(macAddress: String = Self.randomMacAddress)
    
    /// A bridged network interface for the virtual machine.
    ///
    /// - Parameters:
    ///   - hostInterfaceID: The identifier of the host network interface to use for
    ///   bridging. This allows the virtual machine to appear as a separate device on the
    ///   local network, with its own IP address, making it directly accessible to other
    ///   devices on the same network. If nil this value is considered automatically managed
    ///
    ///   - macAddress: The machine hardware address to assign to the VM.
    ///   If not set this falls back to a default, random, value and is considered to be automatically managed by the framerowk.
    ///
    /// The bridged mode is useful for cases where the virtual machine needs to interact with
    /// other devices on the network as if it were a standalone device. The specified
    /// `hostInterfaceID` determines which host interface is used for this connection.
    case bridged(hostInterfaceID: String? = nil, macAddress: String = Self.randomMacAddress)
    
    // MARK: - MAC Validation logic
    
    /// Validates the format of a MAC (Media Access Control) address string.
    ///
    /// This function checks whether the provided string represents a valid MAC address by attempting to initialize
    /// a `VZMACAddress` object with it. If the string is not a valid MAC address, an error is thrown.
    ///
    /// - Parameter value: A `String` representing the MAC address to be validated.
    ///
    /// - Throws:
    ///   - `VZKitError.invalidMacAddress` if the provided string does not conform to a valid MAC address format.
    ///
    /// ## Criteria:
    /// - A valid MAC address must:
    ///   - Consist of six pairs of hexadecimal digits (0–9, A–F) separated by colons (`:`), e.g., `00:1A:2B:3C:4D:5E`.
    ///   - Be compatible with the `VZMACAddress` initializer.
    /// - If the validation fails, the `VZKitError.invalidMacAddress` error is thrown with the invalid value included in the error message.
    public static func macAddressValidation(_ value: String) throws {
        guard let _ = VZMACAddress(string: value) else { throw VZKitError.invalidMacAddress(value) }
    }
    
    // MARK: - Instance properties
    
    /// The MAC (Media Access Control) address associated with the network configuration.
    ///
    /// This computed property retrieves the MAC address based on the specific network topology:
    /// - `.none`: Returns `nil` since no network is configured.
    /// - `.nat`: Returns the MAC address associated with the NAT configuration.
    /// - `.bridged`: Returns the MAC address associated with the bridged configuration.
    ///
    /// - Returns:
    ///   - A `String` representation of the MAC address for `.nat` or `.bridged` configurations.
    ///   - `nil` if the network configuration is `.none` or no MAC address is assigned.
    ///
    /// ## Criteria:
    /// - The returned MAC address depends on the active network configuration:
    ///   - For `.none`, it explicitly returns `nil` since no MAC address is applicable.
    ///   - For `.nat`, it uses the `macAddress` tied to the NAT configuration.
    ///   - For `.bridged`, it uses the `macAddress` tied to the bridged configuration.
    /// - A valid MAC address consists of six pairs of hexadecimal digits separated by colons (e.g., `00:1A:2B:3C:4D:5E`).
    /// - The value is read-only and dynamically derived based on the network topology.
    public var macAddress: String? {
        switch self {
        case .none: nil
        case .nat(let macAddress): macAddress
        case .bridged(_, let macAddress): macAddress
        }
    }
    
    /// The network interface associated with the current network configuration.
    /// This computed property retrieves the specific network interface identifier based on the network topology
    ///
    /// - Returns:
    ///   - A `String` representing the network interface identifier (e.g., `en0`, `en1`) for a `.bridged` configuration.
    ///   - A `nil` value when the `.bridged` configuration is set to use an automatically selected interface.
    ///   - `nil` if the configuration does not involve a bridged network.
    ///
    /// ## Criteria:
    /// - For `.bridged` configurations:
    ///   - Returns the `hostInterfaceID` when explicitly provided.
    ///   - Defaults to a nil value indicating automatic selection if no `hostInterfaceID` is provided.
    /// - For all other configurations, the interface is not applicable, and the property returns `nil`.
    public var hostInterfaceID: String? {
        switch self {
        case .bridged(let hostInterfaceID, _): hostInterfaceID
        default: nil
        }
    }
    
    /// A computed property that provides a localized string representation of the network configuration.
    ///
    /// The `localizedName` property maps network configuration cases to corresponding localized
    /// strings using the `VirtualizationKit.localized` function. Each case is tied to a specific localization key:
    /// - `.none` corresponds to the key `networktopo-none`.
    /// - `.nat` corresponds to the key `networktopo-nat`.
    /// - `.bridged(_, _)` corresponds to the key `networktopo-bridged`.
    ///
    /// - Returns: A `String` that is the localized representation of the network configuration.
    public var localizedName: String {
        switch self {
        case .none: VZKitLocale("networktopo-none").value
        case .nat: VZKitLocale("networktopo-nat").value
        case .bridged: VZKitLocale("networktopo-bridged").value
        }
    }
}
