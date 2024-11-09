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
    
    /// A copy of the Data Transfer Object (DTO) that contains all essential information about the virtual machine (VM) template.
    ///
    /// This property holds an instance of `TemplateType`, which provides the configuration details required
    /// for initializing and managing the virtual machine. The template includes specific settings and parameters
    /// that define the VM’s resources, behavior, and setup.
    public let template: TemplateType
    
    /// A reference to the core `VZVirtualMachine` instance from the Virtualization framework.
    ///
    /// `vzVirtualMachine` serves as the primary interface for controlling the virtual machine, including
    /// operations like starting, stopping, installation procedures, and managing the graphical console.
    /// It encapsulates the underlying `VZVirtualMachine`, giving direct access to essential lifecycle management functionality.
    public let vzVirtualMachine: VZVirtualMachine
    
    /// Manages and tracks the current execution state of the virtual machine, pinned to the main actor.
    ///
    /// `stateManager` is an instance of `StateManager` responsible for observing and updating the `MachineState`
    /// of the virtual machine. Since `stateManager` is tied to `@MainActor`, all state changes and updates are
    /// handled on the main thread, ensuring thread safety for UI updates and other main-thread operations.
    /// The `stateManager` helps centralize and simplify state management within the VM, reducing the need
    /// for manual state tracking within the main view model.
    public let stateManager: MachineStateManager
    
    /// A reference to an instance of `VirtualMachineDelegate`, responsible for handling VM events and updates.
    ///
    /// The `delegate` serves as an intermediary for receiving updates from the `VZVirtualMachine`,
    /// communicating events and state changes to other parts of the application. By connecting directly to
    /// the `VZVirtualMachine` instance, the `delegate` enables efficient event handling for lifecycle transitions
    /// and other VM-related activities.
    public let delegate: MachineDelegate
    
    /// This method provides a standard way to send commands to the `VZVirtualMachine`
    /// and updates the shared state accordingly. If an error occurs, the state is safely reset before propagation.
    /// Since `VZError.virtualMachineLimitExceeded` has a confusing localizedDescription, this method traps it
    /// instead of propagating and throws `VZKitError.appleVMLimitExceeded`. Any case that `Command` provides
    /// is supported by this implementation.
    ///
    /// - Important: Pinned to `@VZKitGlobalActor` for serial dispatch of the commands sent to VMs.
    @VZKitGlobalActor public func sendCommand(_ command: Command) async throws {
                
        do {
            switch command {
            case .start:
                await stateManager.update(with: .starting)
                try await vzVirtualMachine.start()
                await stateManager.update(with: .running)
                
            case .stop:
                await stateManager.update(with: .stopping)
                try await vzVirtualMachine.stop()
                await stateManager.update(with: .stopped)
                
            case .pause:
                await stateManager.update(with: .pausing)
                try await vzVirtualMachine.pause()
                await stateManager.update(with: .paused)
                
            case .resume:
                await stateManager.update(with: .resuming)
                try await vzVirtualMachine.resume()
                await stateManager.update(with: .running)
                
            case .install:
                await stateManager.update(with: .restoring)
                try await MachineInstaller(
                    restoreImage: template.os.installer,
                    vzVirtualMachine: vzVirtualMachine
                ).startInstallation(stateManager)
            }
            
        } catch VZError.virtualMachineLimitExceeded {
            await stateManager.rollback()
            throw VZKitError.appleVMLimitExceeded
            
        } catch {
            await stateManager.rollback()
            throw error
        }
        
    }

    /// The explicit, private, asynchronous init of the data structure. Uses an instance of `ConfigurationBuilder`
    /// to setup the `VZVirtualMachine` object and binds a new instance of `VirtualMachineDelegate` to it.
    ///
    /// - Parameters:
    ///   - template: the data transfer object containing all the information about the VM.
    private init(template: TemplateType) async throws {
        
        self.template = template
        
        let builder = await ConfigurationBuilder(template: template)
        
        self.vzVirtualMachine = VZVirtualMachine(
            configuration: try await builder.createConfiguration(),
            queue: VZKitGlobalActor.queue
        )
        
        self.delegate = .init()
        
        await self.stateManager = .init(self.delegate)
        
        self.vzVirtualMachine.delegate = delegate
    }
}
