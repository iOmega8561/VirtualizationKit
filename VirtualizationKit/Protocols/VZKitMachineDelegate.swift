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
//  VZKitMachineDelegate.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 14/05/24.
//

import Combine

import Virtualization

/// The `VZKitMachineDelegate` protocol.
///
/// Defines a common interface for delegates conforming to `VZVirtualMachineDelegate`.
/// It should act as an intermediary to handle virtual machine state changes, broadcasting these changes through a Combine
/// publisher. The protocol also requires conformation to `Sendable`, making it safe for concurrent use in Swift’s structured concurrency.
///
/// The implementation should be responsible for monitoring the lifecycle of a virtual machine, capturing both graceful shutdowns
/// and forced shutdowns due to errors. When such events occur, the delegate should broadcast updates using `statePublisher`,
/// allowing other parts of the app (such as a view model) to observe and react to state changes.
public protocol VZKitMachineDelegate: VZVirtualMachineDelegate, Sendable {
    
    associatedtype StateType: VZKitMachineState
    
    /// A publisher that emits updates on the virtual machine’s execution state.
    ///
    /// `statePublisher` is a `PassthroughSubject` that broadcasts `StateType` updates when the virtual
    /// machine undergoes state changes, such as stopping gracefully or due to an error. Observing this publisher
    /// allows other components, such as a view model, to stay in sync with the virtual machine’s current state.
    var statePublisher: PassthroughSubject<StateType, Never> { get }
    
    /// Called when the virtual machine has stopped gracefully.
    ///
    /// This method is a stub required by the `VZVirtualMachineDelegate` protocol. It is invoked by the virtual
    /// machine after a graceful shutdown. Upon receiving this event, the delegate should send the current state
    /// through the `statePublisher` so that observers can update accordingly.
    ///
    /// - Parameter virtualMachine: The virtual machine instance that stopped.
    func guestDidStop(_ virtualMachine: VZVirtualMachine)
    
    /// Called when the virtual machine has stopped due to an error.
    ///
    /// This method is a stub required by the `VZVirtualMachineDelegate` protocol. It is invoked when the virtual
    /// machine encounters an error and shuts down forcefully. The delegate should send the current state through the
    /// `statePublisher` to notify observers of the change. Additionally, a task can be launched to present the
    /// error to the user, if desired.
    ///
    /// - Parameters:
    ///   - virtualMachine: The virtual machine instance that stopped.
    ///   - error: The error that caused the virtual machine to stop unexpectedly.
    func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: any Error)
    
    /// Called when a network attachment disconnects from the virtual machine, throwing an error
    ///
    /// This method is a stub optionally required by the `VZVirtualMachineDelegate` protocol. It is invoked when twhen
    /// a network attachment disconnects from the virtual machine, throwing an error. The delegate should log the error. Additionally
    /// a task can be initiated to present the error to the the user, if desired
    ///
    /// - Parameters:
    ///   - virtualMachine: The virtual machine instance that stopped.
    ///   - networkDevice: The network device that has been detached.
    ///   - attachmentWasDisconnectedWithError: The error that has been encountered.
    func virtualMachine(_ virtualMachine: VZVirtualMachine, networkDevice: VZNetworkDevice, attachmentWasDisconnectedWithError error: any Error)
}
