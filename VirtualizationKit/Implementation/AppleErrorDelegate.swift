//
//  AppleErrorDelegate.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 08/11/24.
//

import Virtualization

@preconcurrency import Combine
    
/// The `AppleErrorDelegate` class is a specialized delegate for handling execution errors in a
/// `VZVirtualMachine` instance. Conforming to `VZVirtualMachineDelegate` and `Sendable`, this class
/// captures error-related events during the virtual machine’s lifecycle and broadcasts them through a
/// Combine publisher. This allows other components, such as the state coordinator, to observe and respond to errors
/// that occur during VM execution.
///
/// The delegate logs error messages using the framework’s logging facility, making them available in the
/// Console application, and it provides a centralized mechanism to manage error propagation.
///
/// - Note: This delegate is intended solely for error handling, not for general state change notifications.
final class AppleErrorDelegate: NSObject, VZVirtualMachineDelegate, Sendable {
    
    /// A Combine publisher that emits errors encountered during the virtual machine's execution.
    ///
    /// Observers can subscribe to this `PassthroughSubject` to be notified whenever the virtual machine
    /// stops due to an error or when a network device detaches unexpectedly.
    let errorSubject: PassthroughSubject<Error, Never> = .init()
    
    /// Called when the virtual machine stops due to an error.
    ///
    /// This method is invoked when the virtual machine encounters a fatal error that forces it to shut down.
    /// Upon receiving such an event, the delegate publishes the error via the `errorSubject` and logs the error
    /// using the framework's logging system.
    ///
    /// - Parameters:
    ///   - virtualMachine: The virtual machine instance that has stopped.
    ///   - error: The error that caused the virtual machine to stop unexpectedly.
    func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: any Error) {
        errorSubject.send(error)
        VZKitLogger.default.error(error.localizedDescription)
    }
    
    /// Called when a network device detaches from the virtual machine due to an error.
    ///
    /// This method is triggered when a network attachment disconnects unexpectedly because of an error.
    /// The delegate handles the event by publishing the encountered error through the `errorSubject` and logging
    /// the error details for debugging purposes.
    ///
    /// - Parameters:
    ///   - virtualMachine: The virtual machine instance associated with the network device.
    ///   - networkDevice: The network device that was disconnected.
    ///   - attachmentWasDisconnectedWithError: The error that caused the disconnection.
    func virtualMachine(_ virtualMachine: VZVirtualMachine, networkDevice: VZNetworkDevice, attachmentWasDisconnectedWithError error: any Error) {
        errorSubject.send(error)
        VZKitLogger.default.error(error.localizedDescription)
    }
}
