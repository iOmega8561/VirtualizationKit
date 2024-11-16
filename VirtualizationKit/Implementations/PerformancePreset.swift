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
    public static var maximumAllowedCPUCount: Int {
        min(
            ProcessInfo.processInfo.processorCount,
            VZVirtualMachineConfiguration.maximumAllowedCPUCount
        )
    }
    
    /// Maximum allowed memory size for the host system in bytes.
    public static var maximumAllowedMemorySize: UInt64 {
        min(
            ProcessInfo.processInfo.physicalMemory,
            VZVirtualMachineConfiguration.maximumAllowedMemorySize
        )
    }
    
    /// Minimum allowed CPU core count for the host system.
    public static var minimumAllowedCPUCount: Int {
        VZVirtualMachineConfiguration.minimumAllowedCPUCount
    }
    
    /// Minimum allowed memory size for the host system in bytes.
    public static var minimumAllowedMemorySize: UInt64 {
        VZVirtualMachineConfiguration.minimumAllowedMemorySize
    }
    
    /// Number of CPU cores for the selected preset.
    /// Ensures the value is between minimum and maximum allowed core counts.
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
    
    /// Memory size for the selected preset in bytes.
    /// Ensures the value is between minimum and maximum allowed memory sizes.
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
    
    /// Disk size for the selected preset in bytes.
    /// Predefined for `basic`, `balanced`, and `performance`. Customizable for `custom`.
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
}
