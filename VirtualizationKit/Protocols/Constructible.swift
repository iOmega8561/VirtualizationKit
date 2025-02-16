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
//  Constructible.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 09/01/25.
//

import Virtualization

/// A protocol that defines a constructible type.
///
/// Types conforming to `Constructible` can specify an associated type
/// that defaults to `Self`, enabling generic construction patterns.
protocol Constructible {
    
    /// The type of the object to be constructed.
    associatedtype Product = Self
}

/// A protocol that extends `Constructible` to support asynchronous creation.
///
/// Types conforming to `GenericConstructible` provide a static factory method
/// for creating instances asynchronously, which may throw errors during construction.
protocol GenericConstructible: Constructible {
    
    /// Creates a new instance of the conforming type asynchronously.
    ///
    /// - Returns: A new instance of the conforming type.
    /// - Throws: An error if the creation fails.
    static func create() async throws -> Product
}

/// A protocol that extends `Constructible` for storage-based construction.
///
/// Types conforming to `PersistentConstructible` provide a static factory method
/// that supports creating instances based on a file location and input type.
protocol PersistentConstructible: Constructible {
    
    /// The type of input required to create a new instance.
    associatedtype InputType
    
    /// Creates a new instance of the conforming type at the specified location, using the specified input.
    ///
    /// - Parameters:
    ///   - url: The file system URL where the instance should be created.
    ///   - type: The input required to create the instance.
    /// - Returns: A new instance of the conforming type.
    /// - Throws: An error if the creation fails.
    static func create(at url: URL, type: InputType) throws -> Product
}

/// A protocol that extends `Constructible` for specialized construction.
///
/// Types conforming to `SpecializedConstructible` provide a static factory method
/// that requires an input parameter to create instances.
protocol SpecializedConstructible: Constructible {
    
    /// The type of input required to create a new instance.
    associatedtype InputType
    
    /// Creates a new instance of the conforming type asynchronously, using the specified input.
    ///
    /// - Parameter type: The input required to create the instance.
    /// - Returns: A new instance of the conforming type.
    /// - Throws: An error if the creation fails.
    static func create(type: InputType) async throws -> Product
}
