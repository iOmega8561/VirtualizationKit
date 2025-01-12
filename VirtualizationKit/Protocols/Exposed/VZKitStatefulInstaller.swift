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
//  VZKitStatefulInstaller.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 16/05/24.
//

//// A protocol defining the behavior of a stateful virtual machine installer within the `VZKit` framework.
///
/// The `VZKitStatefulInstaller` protocol specifies the required interface for types responsible for
/// managing the installation of virtual machines. It integrates with a state coordinator to track
/// progress and state transitions during the installation process. Implementations of this protocol
/// leverage Swift's concurrency model to ensure thread safety and isolation.
///
/// ## Features
/// - Integration with a `VZKitStateCoordinator`-conforming type for state and progress tracking.
/// - Asynchronous installation capabilities via the `restoreFromDiskImage()` method.
/// - Designed for safe use in concurrent contexts through the `@VZKitActor` isolation.
///
/// ## Use Cases
/// - Implementing installation logic for virtual machines.
/// - Monitoring and reporting installation progress and state updates.
/// - Ensuring thread-safe and isolated execution of installation tasks.
///
/// ## Example
/// ```swift
/// struct MyMachineInstaller: VZKitStatefulInstaller {
///
///     let restoreImageURL: URL
///     
///     let vzKitStateCoordinator: MyStateCoordinator
///
///     func restoreFromDiskImage() async throws {
///
///         let installer = VZMacOSInstaller(...)
///
///         installer.install {
///
///            // Perform the installation process.
///
///            vzKitStateCoordinator.update(...)
///         }
///     }
/// }
/// ```
public protocol VZKitStatefulInstaller {
    
    // MARK: - Associated Types
    
    /// The type of the state coordinator used for tracking installation progress and state updates.
    ///
    /// This associated type must conform to `VZKitStateCoordinator`, ensuring that conforming types
    /// can integrate seamlessly with the `VZKit` framework's state management system.
    associatedtype StateCoordinator: VZKitStateCoordinator
    
    // MARK: - Properties
    
    /// The state coordinator responsible for tracking the progress and state changes during installation.
    ///
    /// This property provides access to the `StateCoordinator`, enabling conforming types to report
    /// progress and state changes to observers.
    var vzKitStateCoordinator: StateCoordinator { get }
    
    // MARK: - Methods
    
    /// Starts the installation process from a macOS disk image.
    ///
    /// This asynchronous method is responsible for initiating the installation process and updating
    /// the `vzKitStateCoordinator` throughout the operation. Conforming types should handle any errors
    /// encountered during the installation and provide meaningful progress and state updates via the
    /// associated state coordinator.
    ///
    /// - Throws: An error if the installation fails, such as due to a missing restore image,
    ///   configuration issues, or an interrupted operation.
    ///
    /// - Note: This method must be implemented by all conforming types and should ensure thread-safe
    ///         execution through the use of `@VZKitActor`.
    func restoreFromDiskImage() async throws
}
