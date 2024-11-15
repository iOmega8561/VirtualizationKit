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
public enum PerformancePreset: CaseIterable, Codable, Sendable, Hashable {
    
    private typealias Configuration = VZVirtualMachineConfiguration
    
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
    private static var maxCpuCoreCount: Int {
        min(ProcessInfo.processInfo.processorCount, Configuration.maximumAllowedCPUCount)
    }
    
    /// Maximum allowed memory size for the host system in bytes.
    private static var maxMemorySize: UInt64 {
        min(ProcessInfo.processInfo.physicalMemory, Configuration.maximumAllowedMemorySize)
    }
    
    /// Number of CPU cores for the selected preset.
    /// Ensures the value is between minimum and maximum allowed core counts.
    public var cpuCoreCount: Int {
        switch self {
        case .basic:
            return max(Configuration.minimumAllowedCPUCount, Self.maxCpuCoreCount / 4)
            
        case .balanced:
            return max(Configuration.minimumAllowedCPUCount, Self.maxCpuCoreCount / 2)
            
        case .performance:
            return max(Configuration.minimumAllowedCPUCount, Self.maxCpuCoreCount - 2)
            
        case .custom(let desiderCoreCount, _, _):
            return max(min(desiderCoreCount, Self.maxCpuCoreCount), Configuration.minimumAllowedCPUCount)
        }
    }
    
    /// Memory size for the selected preset in bytes.
    /// Ensures the value is between minimum and maximum allowed memory sizes.
    public var memorySize: UInt64 {
        switch self {
        case .basic:
            return max(Configuration.minimumAllowedMemorySize, Self.maxMemorySize / 8)
            
        case .balanced:
            return max(Configuration.minimumAllowedMemorySize, Self.maxMemorySize / 4)
            
        case .performance:
            return max(Configuration.minimumAllowedMemorySize, Self.maxMemorySize / 2)
            
        case .custom(_, let desiredMemorySize, _):
            return max(min(desiredMemorySize, Self.maxMemorySize), Configuration.minimumAllowedMemorySize)
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
