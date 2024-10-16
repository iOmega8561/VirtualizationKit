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
    
    /// `CommandType` should be `enum` and it should provide a case for any command
    /// that the developer using this interface may want to support in their application
    ///
    /// An example would be to have `.start`, `.stop`, `.pause`, `.resume`
    /// It's really up to the dev.
    associatedtype CommandType: CaseIterable
    
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
    ///   - template: the data transfer object containing all the information about the VM.
    static func createMachine(_ template: TemplateType) async -> VZKitResult<TemplateType>
    
    /// This method should provide a standard way to send commands to the `VZVirtualMachine`
    /// and update the shared state accordingly. If an error occurs, the state should be safely reset before propagation.
    ///
    /// - Important: Pinned to `@VZKitGlobalActor` for serial dispatch of the commands sent to VMs.
    @VZKitGlobalActor func sendCommand(_ command: CommandType) async throws
}
