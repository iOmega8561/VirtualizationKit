//
//  Copyright (C) Giuseppe Rocco - All Rights Reserved
//  Unauthorized copying, modification or distribution of this source code,
//  via any medium is strictly prohibited and penally persecutable
//
//  This project and its source code are PROPRIETARY AND CONFIDENTIAL
//  Written by Giuseppe Rocco <giusepperocco38@gmail.com>, May 2024
//
//  -----------------------------------------------------------------------
//
//  VZKitPerformancePreset.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 16/11/24.
//

/// A protocol representing a performance configuration preset for a virtual machine.
///
/// Types conforming to this protocol define preconfigured performance settings,
/// including CPU core count, memory size, and disk size. These presets can be used
/// to quickly configure virtual machines with common performance profiles.
///
/// `VZKitPerformancePreset` conforms to `CaseIterable`, `Codable`, `Sendable`, and `Hashable`,
/// enabling enumeration, serialization, safe concurrent access, and inclusion in collections such as sets or dictionaries.
///
/// ## Conformance Requirements
/// Types conforming to `VZKitPerformancePreset` must implement the following properties:
/// - `cpuCoreCount`: The number of CPU cores allocated to the virtual machine.
/// - `memorySize`: The amount of memory (in bytes) allocated to the virtual machine.
/// - `diskSize`: The size of the virtual machine's storage (in bytes).
///
/// ## Example
/// ```swift
/// enum MyPerformancePreset: VZKitPerformancePreset {
///     case basic
///     case advanced
///     case professional
///
///     var cpuCoreCount: Int {
///         switch self {
///         case .basic: return 2
///         case .advanced: return 4
///         case .professional: return 8
///         }
///     }
///
///     var memorySize: UInt64 {
///         switch self {
///         case .basic: return 2 * 1024 * 1024 * 1024 // 2 GB
///         case .advanced: return 4 * 1024 * 1024 * 1024 // 4 GB
///         case .professional: return 8 * 1024 * 1024 * 1024 // 8 GB
///         }
///     }
///
///     var diskSize: UInt64 {
///         switch self {
///         case .basic: return 20 * 1024 * 1024 * 1024 // 20 GB
///         case .advanced: return 50 * 1024 * 1024 * 1024 // 50 GB
///         case .professional: return 100 * 1024 * 1024 * 1024 // 100 GB
///         }
///     }
/// }
///
/// for preset in MyPerformancePreset.allCases {
///     print("Preset: \(preset), CPU Cores: \(preset.cpuCoreCount), Memory: \(preset.memorySize), Disk: \(preset.diskSize)")
/// }
/// ```
///
/// ## Requirements
///
/// - Note: When using this protocol in a distributed system or across threads, ensure that the conforming types are `Sendable`
///   to avoid potential data races or concurrency issues.
public protocol VZKitPerformancePreset: CaseIterable, Codable, Sendable, Hashable {
    
    /// The number of CPU cores allocated to the virtual machine.
    ///
    /// Use this property to define the virtual machine's processing power.
    /// Higher values correspond to increased computational capacity but also
    /// higher resource usage on the host machine.
    var cpuCoreCount: Int { get }
    
    /// The amount of memory (in bytes) allocated to the virtual machine.
    ///
    /// Use this property to specify the virtual machine's memory capacity.
    /// Ensure that this value does not exceed the available memory on the host machine.
    var memorySize: UInt64 { get }
    
    /// The size of the virtual machine's storage (in bytes).
    ///
    /// This property defines the amount of disk space available to the virtual machine.
    /// Choose a size that accommodates the intended usage while considering storage constraints
    /// on the host machine.
    var diskSize: UInt64 { get }
    
    /// A localized string representing the label of the selected performance preset
    ///
    /// This string provides a human-readable, localized description of the virtual machine's performance preset.
    /// It can be displayed in SwiftUI views to give users contextual information about the configuration.
    /// Localization support ensures that this description is accessible in multiple languages,
    /// improving internationalization and user comprehension.
    var localized: String { get }
}
