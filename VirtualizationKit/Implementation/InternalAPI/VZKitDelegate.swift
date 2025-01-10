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
//  VirtualMachine+Delegate.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 08/11/24.
//

import Virtualization

@preconcurrency import Combine
    
/// The `VZKitDelegate` class.
///
/// Serves as the delegate for a `VZVirtualMachine` instance, conforming to `VZVirtualMachineDelegate`.
/// It acts as an intermediary to handle virtual machine state changes, broadcasting these changes through a Combine
/// publisher. The delegate also conforms to `Sendable`, making it safe for concurrent use in Swift’s structured concurrency.
///
/// This class is responsible for monitoring the lifecycle of a virtual machine, capturing both graceful shutdowns
/// and forced shutdowns due to errors. When such events occur, the delegate publishes updates to the `statePublisher`,
/// allowing other parts of the app (such as a view model) to observe and react to state changes.
final class VZKitDelegate: NSObject, VZVirtualMachineDelegate, Sendable {
    
    /// A publisher that emits updates on the virtual machine’s execution state.
    ///
    /// `statePublisher` is a `PassthroughSubject` that broadcasts `VZVirtualMachine.State` updates when the virtual
    /// machine undergoes state changes, such as stopping gracefully or due to an error. Observing this publisher
    /// allows other components, such as a view model, to stay in sync with the virtual machine’s current state.
    let statePublisher: PassthroughSubject<VZVirtualMachine.State, Never> = .init()
    
    /// Called when the virtual machine has stopped gracefully.
    ///
    /// This method is a stub required by the `VZVirtualVZKitDelegate` protocol. It is invoked by the virtual
    /// machine after a graceful shutdown. Upon receiving this event, the delegate sends the current state
    /// through the `statePublisher` so that observers can update accordingly.
    ///
    /// - Parameter virtualMachine: The virtual machine instance that stopped.
    func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        statePublisher.send(virtualMachine.state)
    }
    
    /// Called when the virtual machine has stopped due to an error.
    ///
    /// This method is a stub required by the `VZVirtualVZKitDelegate` protocol. It is invoked when the virtual
    /// machine encounters an error and shuts down forcefully. The delegate sends the current state through the
    /// `statePublisher` to notify observers of the change. The error is logged using macOS `os_log` facility, making
    /// it viewable in the Console application. Additionally, a task can be launched to present the error to the user, if desired.
    ///
    /// - Parameters:
    ///   - virtualMachine: The virtual machine instance that stopped.
    ///   - error: The error that caused the virtual machine to stop unexpectedly.
    func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: any Error) {
        statePublisher.send(.stopped)
        VZKitLogger.default.error(error.localizedDescription)
    }
    
    /// Called when a network attachment disconnects from the virtual machine, throwing an error
    ///
    /// This method is a stub optionally required by the `VZVirtualVZKitDelegate` protocol. It is invoked when twhen
    /// a network attachment disconnects from the virtual machine, throwing an error. The methods logs the error using VZKitLogger
    /// making it viewable in the Console application. Additionally, a task can be launched to present the error to the user, if desired.
    ///
    /// - Parameters:
    ///   - virtualMachine: The virtual machine instance that stopped.
    ///   - networkDevice: The network device that has been detached.
    ///   - attachmentWasDisconnectedWithError: The error that has been encountered.
    func virtualMachine(_ virtualMachine: VZVirtualMachine, networkDevice: VZNetworkDevice, attachmentWasDisconnectedWithError error: any Error) {
        VZKitLogger.default.error(error.localizedDescription)
    }
}
