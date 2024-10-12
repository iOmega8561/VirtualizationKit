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
//  VirtualMachine.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 15/05/24.
//

@preconcurrency import Virtualization

/// The `VirtualMachine` data structure implementation
///
/// @brief
///    The choice to make it a struct instead of a class derives from the fact that it is not necessary
///    to keep track of the identity of the instanciated object. This struct also conforms to `Sendable`,
///    as required by `VZKitVirtualMachine`.
///
///    - Important: `VZVirtualMachine` IS NOT sendable. We import the `Virtualization` framework using `@preconcurrency`.
///
///    - Important: A VZKitTemplate conforming object is not defined by this framework. It will be responsability of the developer using these
///                 facilities to implement one and correctly use it with this generc data structure.
public struct VirtualMachine<TemplateType: VZKitTemplate>: VZKitVirtualMachine {
    
    /// A copy of the DTO to have all the necessary info about the VM template
    public let template: TemplateType
    
    /// Reference to the `Virtualization` framework object, mainly for running controls, installation and graphical console.
    public let wrappedValue: VZVirtualMachine
    
    /// Reference to an instance of `VirtualMachineDelegate` that will effectively be also bound to the `VZVirtualMachine`
    public let delegate: VirtualMachineDelegate
    
    /// This is a static factory method that returns a Result type, to allow having the error stored but not thrown
    ///
    /// - Parameters:
    ///   - templateDTO: the data transfer object containing all the information about the VM.
    public static func createMachine(_ template: TemplateType) async -> VZKitResult<TemplateType> {
        do {
            return try await .success(VirtualMachine(template: template))
        } catch {
            return .failure(error)
        }
    }
    
    /// This method stops the `VZVirtualMachine` and updates the shared state accordingly.
    /// Provides error handling.
    ///
    /// - Important: Pinned to `@VirtHandlerActor` for serial dispatch of the commands sent to VMs.
    @VZKitGlobalActor public func stop() async throws {
        let oldState = await delegate.updateState(.stopping)
        
        do {
            try await wrappedValue.stop()
            await delegate.updateState(.stopped)
        } catch {
            await delegate.updateState(oldState); throw error
        }
    }
    
    /// This method starts the `VZVirtualMachine` and updates the shared state accordingly.
    /// Provides error handling.
    ///
    /// - Important: Pinned to `@VirtHandlerActor` for serial dispatch of the commands sent to VMs.
    @VZKitGlobalActor public func start() async throws {
        let oldState = await delegate.updateState(.starting)
        
        do {
            try await wrappedValue.start()
            await delegate.updateState(.running)
        } catch {
            await delegate.updateState(oldState); throw error
        }
    }
    
    /// This method pauses the `VZVirtualMachine` and updates the shared state accordingly.
    /// Provides error handling.
    ///
    /// - Important: Pinned to `@VirtHandlerActor` for serial dispatch of the commands sent to VMs.
    @VZKitGlobalActor public func pause() async throws {
        let oldState = await delegate.updateState(.pausing)
        
        do {
            try await wrappedValue.pause()
            await delegate.updateState(.paused)
        } catch {
            await delegate.updateState(oldState); throw error
        }
    }
    
    /// This method resumes the `VZVirtualMachine` and updates the shared state accordingly.
    ///
    /// - Important: Pinned to `@VirtHandlerActor` for serial dispatch of the commands sent to VMs.
    @VZKitGlobalActor public func resume() async throws {
        let oldState = await delegate.updateState(.resuming)
        
        do {
            try await wrappedValue.resume()
            await delegate.updateState(.running)
        } catch {
            await delegate.updateState(oldState); throw error
        }
    }
    
    /// This starts the installation procedure for the `VZVirtualMachine`.
    /// Creates an appropriate installer and updates the shared state accordingly.
    ///
    /// - Important: Allows the caller viewModel to handle the error by re-throwing.
    ///
    /// - Important: Pinned to `@VirtHandlerActor` for serial dispatch of the commands sent to VMs.
    @VZKitGlobalActor public func install() async throws {
        await delegate.updateState(.starting)
    
        do {
            try await VirtualMachineInstaller(
                restoreImage: template.os.installer,
                machine: wrappedValue
            ).startInstallation()
        } catch {
            await delegate.updateState(.stopped); throw error
        }
    }

    /// The explicit asynchronous init of the data structure. Uses an instance of `VirtualMachineConfigurator`
    /// to setup the `VZVirtualMachine` object and binds a newly created delegate to it.
    ///
    /// - Parameters:
    ///   - template: the data transfer object containing all the information about the VM.
    init(template: TemplateType) async throws {
        
        self.template = template
        
        let configurator = VirtualMachineConfigurator(template: template)
                
        self.delegate = await VirtualMachineDelegate()
        
        self.wrappedValue = VZVirtualMachine(
            configuration: try await configurator.createConfiguration(),
            queue: VZKitGlobalActor.queue
        )
        
        self.wrappedValue.delegate = delegate
    }
}
