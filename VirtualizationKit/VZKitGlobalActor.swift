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
//  VZKitGlobalActor.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 18/05/24.
//

import Virtualization

/// VirtualizationKit global actor's custom executor implementation
private final class VZKitGlobalActorExecutor: SerialExecutor {
    private let queue: DispatchQueue
    
    func enqueue(_ job: UnownedJob) {
        queue.async {
            job.runSynchronously(on: self.asUnownedSerialExecutor())
        }
    }
    
    func asUnownedSerialExecutor() -> UnownedSerialExecutor {
        return UnownedSerialExecutor(ordinary: self)
    }
    
    init(queue: DispatchQueue) {
        self.queue = queue
    }
}

/// VirtualizationKit's custom global actor
///
/// @brief
///    This will be the actor on which every virtual machine command will be executed.
///    Having a global actor designed to do that is extremely useful, as it simply allows to
///    mark all the affected methods with it's property wrapper instead of manually calling
///    the shared dispatch queue
@globalActor public final actor VZKitGlobalActor: GlobalActor {
    
    /// This is shared queue that this actor will use for it's executor
    public static nonisolated let queue = DispatchQueue(label: "VirtualizationActor")
    
    /// This is shared singleton instance of this actor
    public static nonisolated let shared = VZKitGlobalActor()
    
    private static let executor = VZKitGlobalActorExecutor(queue: queue)
    
    public static let sharedUnownedExecutor: UnownedSerialExecutor = executor.asUnownedSerialExecutor()

    public nonisolated var unownedExecutor: UnownedSerialExecutor {
        Self.sharedUnownedExecutor
    }
}
