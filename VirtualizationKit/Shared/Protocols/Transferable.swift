//
//  Copyright 2025 Giuseppe Rocco
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
//  -----------------------------------------------------------------------
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
