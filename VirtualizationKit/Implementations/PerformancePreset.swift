//
//  PerformancePreset.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 15/11/24.
//

import Foundation

import Virtualization

/// PerformancePreset defines hardware configurations for virtual machines.
/// It provides predefined presets and a customizable option for fine-tuned resources.
///
/// Presets:
/// - `basic`: Minimal resource usage.
/// - `balanced`: General-purpose configuration.
/// - `performance`: Maximizes resource allocation for performance.
/// - `custom`: User-defined configuration.
///
/// UInt64 values for memorySize and diskSize are multiples of 1 MB.
public enum PerformancePreset: VZKitPerformancePreset {
    
    /// List of all performance presets.
    public static let allCases: [PerformancePreset] = [
        .basic,
        .balanced,
        .performance,
        .custom()
    ]
    
    /// Minimal configuration for lightweight workloads.
    case basic
    
    /// Balanced configuration for general-purpose workloads.
    case balanced
    
    /// High-performance configuration maximizing resources.
    case performance
    
    /// Custom configuration with user-defined hardware capabilities.
    ///
    /// - Important: It is responsability of the developer using this framework to ensure that parameter values for custom case
    ///  are within boundaries of the user's host system. Out of boundary values will be handled gracefully by this framework simply by
    ///  respecting the host capabilities, but it's not recommended to allow the user to go beyond what his system can do.
    ///
    /// - Important: it's especially necessary to avoid setting negative values on UInt64 since this will result in runtime crashes.
    ///
    /// - Parameters:
    ///   - desiderCoreCount: Desired number of CPU cores (defaults to `balanced` preset).
    ///   - desiredMemorySize: Desired memory size in bytes (defaults to `balanced` preset).
    ///   - desiredDiskSize: Desired disk size in bytes (defaults to `balanced` preset).
    case custom(
        desiderCoreCount: Int = Self.balanced.cpuCoreCount,
        desiredMemorySize: UInt64 = Self.balanced.memorySize,
        desiredDiskSize: UInt64 = Self.balanced.diskSize
    )
    
    /// Maximum allowed CPU core count for the host system.
    /// - Returns: The smaller of:
    ///   - The total number of processor cores available on the host system (`ProcessInfo.processInfo.processorCount`).
    ///   - The maximum CPU core count permitted by the `VZVirtualMachineConfiguration` class.
    /// - Criteria: Ensures that the virtual machine does not attempt to use more cores than the host system has available or
    ///   exceed the virtualization framework's limits.
    public static var maximumAllowedCPUCount: Int {
        min(
            ProcessInfo.processInfo.processorCount,
            VZVirtualMachineConfiguration.maximumAllowedCPUCount
        )
    }
    
    /// Maximum allowed memory size for the host system in bytes.
    /// - Returns: The smaller of:
    ///   - The total physical memory available on the host system (`ProcessInfo.processInfo.physicalMemory`).
    ///   - The maximum memory size permitted by the `VZVirtualMachineConfiguration` class.
    /// - Criteria: Ensures that the virtual machine does not allocate more memory than the host system has available or
    ///   exceed the virtualization framework's limits.
    public static var maximumAllowedMemorySize: UInt64 {
        min(
            ProcessInfo.processInfo.physicalMemory,
            VZVirtualMachineConfiguration.maximumAllowedMemorySize
        )
    }
    
    /// Minimum allowed CPU core count for the host system.
    /// - Returns: The minimum CPU core count required by the `VZVirtualMachineConfiguration` class.
    /// - Criteria: Guarantees that the virtual machine configuration meets the virtualization framework's minimum requirement
    ///   for CPU cores, independent of the host system's hardware.
    public static var minimumAllowedCPUCount: Int {
        VZVirtualMachineConfiguration.minimumAllowedCPUCount
    }
    
    /// Minimum allowed memory size for the host system in bytes.
    /// - Returns: The minimum memory size required by the `VZVirtualMachineConfiguration` class.
    /// - Criteria: Guarantees that the virtual machine configuration meets the virtualization framework's minimum requirement
    ///   for memory size, independent of the host system's hardware.
    public static var minimumAllowedMemorySize: UInt64 {
        VZVirtualMachineConfiguration.minimumAllowedMemorySize
    }
    
    /// The number of CPU cores assigned for the selected virtual machine preset.
    ///
    /// This computed property determines the CPU core count based on the selected preset configuration.
    /// It ensures the value is within the valid range defined by the virtual machine's capabilities,
    /// specifically between the minimum and maximum allowable core counts.
    ///
    /// ## Overview
    ///
    /// The property evaluates the selected preset and applies logic to calculate the CPU core count:
    ///
    /// - **Basic Preset (`.basic`)**:
    ///   - Designed for lightweight workloads.
    ///   - Allocates a quarter of the maximum allowable CPU cores, ensuring at least the system's maximum allowed core count.
    ///   - Formula: `max(VZVirtualMachineConfiguration.maximumAllowedCPUCount, Self.maximumAllowedCPUCount / 4)`
    ///
    /// - **Balanced Preset (`.balanced`)**:
    ///   - Balances performance and resource usage.
    ///   - Allocates half of the maximum allowable CPU cores, ensuring at least the system's minimum allowed core count.
    ///   - Formula: `max(VZVirtualMachineConfiguration.minimumAllowedCPUCount, Self.maximumAllowedCPUCount / 2)`
    ///
    /// - **Performance Preset (`.performance`)**:
    ///   - Optimized for high performance.
    ///   - Allocates the maximum allowable CPU cores minus a fixed buffer of 2, ensuring at least the system's minimum allowed core count.
    ///   - Formula: `max(VZVirtualMachineConfiguration.minimumAllowedCPUCount, Self.maximumAllowedCPUCount - 2)`
    ///
    /// - **Custom Preset (`.custom`)**:
    ///   - Allows users to specify a desired core count.
    ///   - Ensures the desired core count stays within the valid range:
    ///     - At least the system's minimum allowed core count.
    ///     - At most the system's maximum allowed core count.
    ///   - Formula: `max(min(desideredCoreCount, Self.maximumAllowedCPUCount), VZVirtualMachineConfiguration.minimumAllowedCPUCount)`
    ///
    /// ## Validations
    /// - `VZVirtualMachineConfiguration.minimumAllowedCPUCount`: The system-defined minimum CPU core count.
    /// - `VZVirtualMachineConfiguration.maximumAllowedCPUCount`: The system-defined maximum CPU core count.
    /// - `Self.maximumAllowedCPUCount`: A static property defining the maximum CPU core count for the virtual machine configuration.
    ///
    /// ## Use Case
    /// The `cpuCoreCount` property ensures that the CPU configuration of a virtual machine adheres to hardware limitations
    /// while optimizing for the selected workload preset. The custom preset provides flexibility for user-defined configurations.
    public var cpuCoreCount: Int {
        switch self {
        case .basic:
            return max(
                VZVirtualMachineConfiguration.maximumAllowedCPUCount,
                Self.maximumAllowedCPUCount / 4
            )
            
        case .balanced:
            return max(
                VZVirtualMachineConfiguration.minimumAllowedCPUCount,
                Self.maximumAllowedCPUCount / 2
            )
            
        case .performance:
            return max(
                VZVirtualMachineConfiguration.minimumAllowedCPUCount,
                Self.maximumAllowedCPUCount - 2
            )
            
        case .custom(let desideredCoreCount, _, _):
            return max(
                min(
                    desideredCoreCount,
                    Self.maximumAllowedCPUCount
                ),
                VZVirtualMachineConfiguration.minimumAllowedCPUCount
            )
        }
    }
    
    /// The memory size in bytes assigned for the selected virtual machine preset.
    ///
    /// This computed property determines the memory size based on the selected preset configuration.
    /// It ensures the memory size value adheres to the valid range defined by the virtual machine's capabilities,
    /// specifically between the minimum and maximum allowable memory sizes.
    ///
    /// ## Overview
    ///
    /// The property evaluates the selected preset and calculates the memory size using the following logic:
    ///
    /// - **Basic Preset (`.basic`)**:
    ///   - Designed for lightweight workloads with minimal resource usage.
    ///   - Allocates one-eighth of the maximum allowable memory size, ensuring at least the system's minimum allowed memory size.
    ///   - Formula: `max(VZVirtualMachineConfiguration.minimumAllowedMemorySize, Self.maximumAllowedMemorySize / 8)`
    ///
    /// - **Balanced Preset (`.balanced`)**:
    ///   - Balances performance and memory usage.
    ///   - Allocates one-fourth of the maximum allowable memory size, ensuring at least the system's minimum allowed memory size.
    ///   - Formula: `max(VZVirtualMachineConfiguration.minimumAllowedMemorySize, Self.maximumAllowedMemorySize / 4)`
    ///
    /// - **Performance Preset (`.performance`)**:
    ///   - Optimized for high-performance workloads.
    ///   - Allocates half of the maximum allowable memory size, ensuring at least the system's minimum allowed memory size.
    ///   - Formula: `max(VZVirtualMachineConfiguration.minimumAllowedMemorySize, Self.maximumAllowedMemorySize / 2)`
    ///
    /// - **Custom Preset (`.custom`)**:
    ///   - Allows users to specify a desired memory size.
    ///   - Ensures the desired memory size stays within the valid range:
    ///     - At least the system's minimum allowed memory size.
    ///     - At most the system's maximum allowed memory size.
    ///   - Formula: `max(min(desiredMemorySize, Self.maximumAllowedMemorySize), VZVirtualMachineConfiguration.minimumAllowedMemorySize)`
    ///
    /// ## Validations
    /// - `VZVirtualMachineConfiguration.minimumAllowedMemorySize`: The system-defined minimum memory size in bytes.
    /// - `VZVirtualMachineConfiguration.maximumAllowedMemorySize`: The system-defined maximum memory size in bytes.
    /// - `Self.maximumAllowedMemorySize`: A static property defining the maximum memory size for the virtual machine configuration.
    ///
    /// ## Use Case
    /// The `memorySize` property ensures the memory configuration of a virtual machine adheres to hardware limitations
    /// while optimizing for the selected workload preset. The custom preset provides flexibility for user-defined configurations.
    public var memorySize: UInt64 {
        switch self {
        case .basic:
            return max(
                VZVirtualMachineConfiguration.minimumAllowedMemorySize,
                Self.maximumAllowedMemorySize / 8
            )
            
        case .balanced:
            return max(
                VZVirtualMachineConfiguration.minimumAllowedMemorySize,
                Self.maximumAllowedMemorySize / 4
            )
            
        case .performance:
            return max(
                VZVirtualMachineConfiguration.minimumAllowedMemorySize,
                Self.maximumAllowedMemorySize / 2
            )
            
        case .custom(_, let desiredMemorySize, _):
            return max(
                min(
                    desiredMemorySize,
                    Self.maximumAllowedMemorySize
                ),
                VZVirtualMachineConfiguration.minimumAllowedMemorySize
            )
        }
    }
    
    /// The disk size in bytes assigned for the selected virtual machine preset.
    ///
    /// This computed property determines the disk size based on the selected preset configuration.
    /// Predefined sizes are used for standard presets (`basic`, `balanced`, `performance`), while
    /// the `custom` preset allows user-defined disk sizes.
    ///
    /// ## Overview
    ///
    /// The property evaluates the selected preset and assigns the disk size as follows:
    ///
    /// - **Basic Preset (`.basic`)**:
    ///   - Suitable for lightweight workloads or minimal storage requirements.
    ///   - Allocates a fixed disk size of 32 GiB (32 * 1024 * 1024 * 1024 bytes).
    ///
    /// - **Balanced Preset (`.balanced`)**:
    ///   - Designed for typical workloads with moderate storage needs.
    ///   - Allocates a fixed disk size of 64 GiB (64 * 1024 * 1024 * 1024 bytes).
    ///
    /// - **Performance Preset (`.performance`)**:
    ///   - Optimized for resource-intensive workloads requiring significant storage.
    ///   - Allocates a fixed disk size of 128 GiB (128 * 1024 * 1024 * 1024 bytes).
    ///
    /// - **Custom Preset (`.custom`)**:
    ///   - Allows users to specify a desired disk size.
    ///   - Returns the user-defined `desiredDiskSize` without modification.
    ///
    /// ## Validations
    /// Unlike `cpuCoreCount` and `memorySize`, this property does not enforce minimum or maximum bounds.
    /// Users are responsible for ensuring the validity of the `desiredDiskSize` when using the `custom` preset.
    ///
    /// ## Use Case
    /// The `diskSize` property simplifies virtual machine storage configuration by providing predefined
    /// disk sizes for common presets while allowing full customization for specific needs. The property is
    /// particularly useful for ensuring quick setup with standard presets or detailed control with the custom preset.
    public var diskSize: UInt64 {
        switch self {
        case .basic:
            return 32 * 1024 * 1024 * 1024
            
        case .balanced:
            return 64 * 1024 * 1024 * 1024
            
        case .performance:
            return 128 * 1024 * 1024 * 1024
            
        case .custom(_, _, let desiredDiskSize):
            return desiredDiskSize
        }
    }
    
    /// A computed property that provides a localized string for different performance presets.
    ///
    /// The localization keys are determined by the case of the enum instance.
    /// - Returns: A `String` containing the localized value for the performance preset.
    public var localized: String {
        switch self {
        case .basic:
            return VirtualizationKit.localized("perfpreset-basic")
            
        case .balanced:
            return VirtualizationKit.localized("perfpreset-balanced")
            
        case .performance:
            return VirtualizationKit.localized("perfpreset-performance")
            
        case .custom(_, _, _):
            return VirtualizationKit.localized("perfpreset-custom")
        }
    }
}
