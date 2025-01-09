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
//  VZKitMachineInstaller.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 16/05/24.
//

import Combine
import Virtualization

/// The `VZKitMachineInstaller` protocol defines a generic interface for implementing virtual machine (VM) installers
/// within the application. This protocol abstracts the installation process, specifying only the essential requirements
/// for initiating and managing the VM installation. It is designed to be flexible and does not assume any specific way
/// of presenting information to the end user, making it adaptable for different installation contexts.
///
/// Conforming types are required to provide a restore image URL, a reference to the virtual machine instance,
/// and an installation method that operates on a specified state manager.
protocol VZKitMachineInstaller: Sendable {
    
    /// The associated type that specifies the type of state manager required for managing the installation process.
    ///
    /// `StateManagerType` must conform to `VZKitStateCoordinator`, which defines the necessary functionality for tracking
    /// the VM's execution state throughout the installation. This associated type allows the installer to interact with
    /// state managers of varying implementations, providing flexibility and reuse.
    associatedtype StateManagerType: VZKitStateCoordinator
    
    /// The URL pointing to the restore image needed for the VM installation.
    ///
    /// `restoreImage` holds the URL of the installation image used to install the guest operating system.
    /// This image provides the data required for the setup, such as operating system files, and is typically an IPSW, ISO or
    /// other VM-compatible image format. The installer will use this URL to access the restore image during installation.
    var restoreImage: URL { get }
    
    /// A reference to the `VZVirtualMachine` instance associated with the installation.
    ///
    /// `vzVirtualMachine` represents the virtual machine that will be set up or configured by the installer. This reference allows
    /// the installer to perform operations directly on the VM instance, such as starting and stopping the machine or applying
    /// configuration changes during the installation process.
    var vzVirtualMachine: VZVirtualMachine { get }
    
    /// Starts the installation process on the specified state manager.
    ///
    /// The `startInstallation(_:)` method is responsible for initiating and managing the virtual machine installation.
    /// This function operates asynchronously on the `@VZKitActor` to ensure thread safety and isolation,
    /// Implementations of this method should update the `stateManager` throughout the installation to reflect the progress
    /// and state changes of the VM.
    ///
    /// - Parameter stateManager: An instance of `StateManagerType`, responsible for tracking the VM's execution state
    ///   during installation. The state manager provides observers with updates on the installation's progress and
    ///   state changes.
    ///
    /// - Throws: An error if the installation process encounters an issue, such as a missing restore image, configuration
    ///   error, or an interrupted operation.
    @VZKitActor func startInstallation(_ stateManager: StateManagerType) async throws
}
