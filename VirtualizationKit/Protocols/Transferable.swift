//
//  Transferable.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 10/01/25.
//

/// A type that can be safely transferred across concurrency domains and persisted.
///
/// The `Transferable` typealias combines `Codable`, `Hashable`, and `Sendable`,
/// ensuring that conforming types can be:
/// - **Encoded and decoded** (`Codable`): Supports serialization and deserialization,
///   making it suitable for data persistence and network communication.
/// - **Hashed** (`Hashable`): Can be used as dictionary keys and stored in sets,
///   enabling efficient lookup and uniqueness enforcement.
/// - **Safely sent across concurrency domains** (`Sendable`): Ensures thread safety
///   when used in Swift's concurrent programming model.
///
/// This typealias is useful for defining data structures that need to be stored,
/// transmitted, and safely shared across different execution contexts.
///
/// ### Example
/// ```swift
/// struct User: Transferable {
///     let id: UUID
///     let name: String
/// }
/// ```
public typealias Transferable = Codable & Hashable & Sendable
