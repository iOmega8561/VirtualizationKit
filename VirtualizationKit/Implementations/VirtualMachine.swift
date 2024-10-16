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
/// - Important: `VZVirtualMachine` IS NOT sendable. We import the `Virtualization` framework using `@preconcurrency`.
///
/// - Important: A VZKitTemplate conforming object is not defined by this framework. It will be responsability of the developer using these
///              facilities to implement one and correctly use it with this generc data structure.
public struct VirtualMachine<TemplateType: VZKitTemplate>: VZKitVirtualMachine {
    
    /// `Command` is a `CaseIterable` conforming `enum` and it provides a case for any command
    /// that is supported by this default implementation of `VZKitVirtualMachine`
    public enum Command: CaseIterable {
        case start
        case stop
        case pause
        case resume
        case install
    }
    
    /// A copy of the DTO to have all the necessary info about the VM template
    public let template: TemplateType
    
    /// Reference to the `Virtualization` framework object, mainly for running controls, installation and graphical console.
    public let wrappedValue: VZVirtualMachine
    
    /// Reference to an instance of `VirtualMachineDelegate` that will effectively be also bound to the `VZVirtualMachine`
    public let delegate: VirtualMachineDelegate
    
    /// Static factory method of this default implementation,
    ///
    /// - Parameters:
    ///   - template: the data transfer object containing all the information about the VM.
    ///
    /// - Returns:VZKitResult<TemplateType> so that the caller can store any eventual error to something with it.
    public static func createMachine(_ template: TemplateType) async -> VZKitResult<TemplateType> {
        do {
            return try await .success(VirtualMachine(template: template))
        } catch {
            return .failure(error)
        }
    }
    
    /// This method provides a standard way to send commands to the `VZVirtualMachine`
    /// and updates the shared state accordingly. If an error occurs, the state is safely reset before propagation.
    /// Since `VZError.virtualMachineLimitExceeded` has a confusing localizedDescription, this method traps it
    /// instead of propagating and throws `VZKitError.appleVMLimitExceeded`. Any case that `Command` provides
    /// is supported by this implementation.
    ///
    /// - Important: Pinned to `@VZKitGlobalActor` for serial dispatch of the commands sent to VMs.
    @VZKitGlobalActor public func sendCommand(_ command: Command) async throws {
        
        let oldState: VirtualMachineState
        
        do {
            switch command {
            case .start:
                oldState = await delegate.updateState(.starting)
                try await wrappedValue.start()
                await delegate.updateState(.running)
                
            case .stop:
                oldState = await delegate.updateState(.stopping)
                try await wrappedValue.stop()
                await delegate.updateState(.stopped)
                
            case .pause:
                oldState = await delegate.updateState(.pausing)
                try await wrappedValue.pause()
                await delegate.updateState(.paused)
                
            case .resume:
                oldState = await delegate.updateState(.resuming)
                try await wrappedValue.resume()
                await delegate.updateState(.running)
                
            case .install:
                oldState = await delegate.updateState(.starting)
                try await VirtualMachineInstaller(
                    restoreImage: template.os.installer,
                    machine: wrappedValue
                ).startInstallation()
            }
            
        } catch VZError.virtualMachineLimitExceeded {
            await delegate.updateState(oldState)
            throw VZKitError.appleVMLimitExceeded
            
        } catch {
            await delegate.updateState(oldState)
            throw error
        }
        
    }

    /// The explicit, private, asynchronous init of the data structure. Uses an instance of `VirtualMachineConfigurator`
    /// to setup the `VZVirtualMachine` object and binds a new instance of `VirtualMachineDelegate` to it.
    ///
    /// - Parameters:
    ///   - template: the data transfer object containing all the information about the VM.
    private init(template: TemplateType) async throws {
        
        self.template = template
        
        let configurator = await VirtualMachineConfigurator(template: template)
                
        self.delegate = await VirtualMachineDelegate()
        
        self.wrappedValue = VZVirtualMachine(
            configuration: try await configurator.createConfiguration(),
            queue: VZKitGlobalActor.queue
        )
        
        self.wrappedValue.delegate = delegate
    }
}
