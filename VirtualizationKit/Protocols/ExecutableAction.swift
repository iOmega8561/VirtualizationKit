//
//  ExecutableAction.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 15/02/25.
//

/// A protocol defining executable actions for controlling a virtual machine.
///
/// Conforming types represent high-level commands that can be issued to a virtual machine,
/// such as starting, stopping, pausing, and resuming its execution. Each action is modeled
/// as a static member or method, allowing for a clear, type-safe specification of commands.
///
/// Conformance to `Sendable` ensures that instances of the conforming types are safe to use
/// across concurrency domains.
///
/// ### Associated Type
/// - `StartOptions`: A type that encapsulates the options or parameters needed to start a virtual machine.
///   This type allows customization of the start action, such as specifying configuration details.
///   It is constrained to `NSObject` so that a default initializer is available.
///
/// ### Requirements
/// - `static func start(options: StartOptions) -> Self`
///   Creates an instance representing a start action with the provided options.
/// - `static var stop: Self { get }`
///   A static property that represents a stop action.
/// - `static var pause: Self { get }`
///   A static property that represents a pause action.
/// - `static var resume: Self { get }`
///   A static property that represents a resume action.
public protocol ExecutableAction: Sendable {
    
    /// The type that encapsulates the options required to start a virtual machine.
    ///
    /// Constrained to `NSObject`, ensuring a default initializer is available.
    associatedtype StartOptions: NSObject
    
    /// Creates an action to start a virtual machine with the specified options.
    ///
    /// - Parameter options: An instance of `StartOptions` containing the parameters needed to
    ///   configure the start action.
    /// - Returns: An instance of the conforming type representing the start action.
    static func start(options: StartOptions) -> Self
    
    /// Represents the action to stop a virtual machine.
    static var stop: Self { get }
    
    /// Represents the action to pause a virtual machine.
    static var pause: Self { get }
    
    /// Represents the action to resume a paused virtual machine.
    static var resume: Self { get }
}

/// Provides a default implementation for the no-argument `start()` method.
///
/// This extension leverages the fact that `StartOptions` is an `NSObject` (which provides
/// a default initializer via `init()`). Thus, calling `start()` without parameters automatically
/// uses a default-initialized instance of `StartOptions`.
public extension ExecutableAction {
        
    /// Creates an action to start a virtual machine using the default options.
    ///
    /// This convenience method calls `start(options:)` with a default-constructed instance of
    /// `StartOptions`.
    ///
    /// - Returns: An instance representing the start action with default configuration.
    static func start() -> Self {
        start(options: .init())
    }
}
