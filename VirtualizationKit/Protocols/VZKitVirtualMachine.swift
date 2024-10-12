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
//  VZKitVirtualMachine.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 14/05/24.
//

import Virtualization

/// VZKitVirtualMachine protocol
///
/// @brief
///    This protocol defines how a Virtual Machine should be implemented in this application
public protocol VZKitVirtualMachine: Sendable {
    
    associatedtype TemplateType: VZKitTemplate
    
    associatedtype DelegateType: VZKitMachineDelegate
    
    /// A copy of the DTO to have all the necessary info about the VM template
    var template: TemplateType { get }
    
    /// Reference to an instance of `VZKitMachineDelegate` conforming class.
    /// that will effectively be also bound to the `VZVirtualMachine` instance.
    var delegate: DelegateType { get }

    /// Reference to the `Virtualization` framework object, mainly for running controls, installation and graphical console.
    var wrappedValue: VZVirtualMachine { get }

    /// Static factory method.
    /// Returns a `Result<Self, Error>` type, in order to have a rapresentation of eventual errors, to do something with them in the UI.
    ///
    /// - Parameters:
    ///   - templateDTO: the data transfer object containing all the information about the VM.
    static func createMachine(_ template: TemplateType) async -> VZKitResult<TemplateType>
    
    /// This method should stop the `VZVirtualMachine` and eventually update the shared state accordingly.
    ///
    /// - Important: Pinned to `@VZKitGlobalActor`, since any call to the vm power control methods should be on this queue.
    @VZKitGlobalActor func stop() async throws
    
    /// This method should start the `VZVirtualMachine` and eventually update the shared state accordingly.
    ///
    /// - Important: Pinned to `@VZKitGlobalActor`, since any call to the vm power control methods should be on this queue.
    @VZKitGlobalActor func start() async throws
    
    /// This method should pause the `VZVirtualMachine` and eventually update the shared state accordingly.
    ///
    /// - Important: Pinned to `@VZKitGlobalActor`, since any call to the vm power control methods should be on this queue.
    @VZKitGlobalActor func pause() async throws
    
    /// This method should resume the `VZVirtualMachine` and eventually update the shared state accordingly.
    ///
    /// - Important: Pinned to `@VZKitGlobalActor`, since any call to the vm power control methods should be on this queue.
    @VZKitGlobalActor func resume() async throws
    
    /// This method should handler the installation of the guest operating system.
    ///
    /// - Important: Pinned to `@VZKitGlobalActor`, since any call to the vm power control methods should be on this queue.
    @VZKitGlobalActor func install() async throws
}
