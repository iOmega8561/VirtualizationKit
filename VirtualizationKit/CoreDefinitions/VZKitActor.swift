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
//  VZKitActor.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 18/05/24.
//

import Virtualization

/// The custom global actor for `VirtualizationKit`.
///
/// This global actor serves as the execution context for all virtual machine commands within
/// the `VirtualizationKit` framework. By defining a dedicated global actor, virtual machine-related
/// methods and tasks can be marked with the actor’s property wrapper, ensuring they run on a shared,
/// serially executed dispatch queue. This provides thread safety and simplifies code by eliminating
/// the need to explicitly reference a shared dispatch queue in each method.
@globalActor public final actor VZKitActor: GlobalActor {
    
    /// A custom serial executor implementation for the `VZKitActor`.
    ///
    /// This executor is responsible for executing jobs on a serial `DispatchQueue`, ensuring
    /// that all tasks submitted to the `VZKitActor` are executed sequentially. It
    /// implements `SerialExecutor`, which provides the functionality needed to manage job
    /// execution in a controlled, synchronous manner.
    private final class Executor: SerialExecutor {
        
        /// The dispatch queue on which the executor performs tasks.
        ///
        /// This queue ensures tasks are executed in the order they are received, providing a serial execution
        /// model. The queue is injected during initialization, allowing flexibility in choosing a specific
        /// queue for job execution.
        private let queue: DispatchQueue
        
        /// Enqueues a job to be executed asynchronously on the executor's dispatch queue.
        ///
        /// - Parameter job: The job to be executed. This job is unowned, meaning it is expected to be managed
        ///   and retained externally. The job is executed synchronously on the serial executor, maintaining
        ///   ordering and thread safety.
        func enqueue(_ job: UnownedJob) {
            queue.async {
                job.runSynchronously(on: self.asUnownedSerialExecutor())
            }
        }
        
        /// Returns an unowned serial executor instance for this executor.
        ///
        /// - Returns: An `UnownedSerialExecutor` instance referencing this executor. This allows
        ///   for unowned access to the executor while ensuring that the serial execution model is preserved.
        func asUnownedSerialExecutor() -> UnownedSerialExecutor {
            return UnownedSerialExecutor(ordinary: self)
        }
        
        /// Initializes a new instance of `Executor` with a specific dispatch queue.
        ///
        /// - Parameter queue: The dispatch queue used to perform tasks submitted to the executor.
        init(queue: DispatchQueue) {
            self.queue = queue
        }
    }
    
    /// The shared dispatch queue used by this actor's executor.
    ///
    /// All tasks submitted to this actor are executed on this queue, ensuring serialized execution
    /// within the `VirtualizationKit` context. This queue is shared and non isolated so that we can
    /// use this reference when creating a virtual machine: the initializer for VZVirtualMachine optionally takes a queue as parameter.
    public static nonisolated let queue = DispatchQueue(label: "VZKitActor")
    
    /// The shared singleton instance of `VZKitActor`.
    ///
    /// This instance provides a single point of access to the global actor, ensuring that all
    /// virtual machine commands are executed in the same execution context.
    public static nonisolated let shared = VZKitActor()
    
    /// The internal executor instance responsible for serial execution of tasks.
    ///
    /// This executor is initialized with `queue` and manages the dispatching of tasks, enforcing
    /// serialized execution for all jobs submitted to `VZKitActor`.
    private static let executor = Executor(queue: queue)
    
    /// An unowned reference to the executor, used to enforce the actor's serial execution model.
    ///
    /// This property provides unowned access to the executor, allowing the actor to maintain
    /// serialized task execution while avoiding retain cycles.
    public static let sharedUnownedExecutor: UnownedSerialExecutor = executor.asUnownedSerialExecutor()

    /// The unowned executor instance associated with this actor.
    ///
    /// By using an unowned executor, the actor ensures that tasks are executed serially
    /// without retaining the executor instance. This nonisolated property is used to maintain
    /// thread safety across all virtual machine commands managed by the actor.
    public nonisolated var unownedExecutor: UnownedSerialExecutor {
        Self.sharedUnownedExecutor
    }
}
