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
//  VZKitSpecializedConstructible.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 09/01/25.
//

/// A protocol that extends `VZKitConstructible` for specialized construction.
///
/// Types conforming to `VZKitSpecializedConstructible` provide a static factory method
/// that requires an input parameter to create instances.
protocol VZKitSpecializedConstructible: VZKitConstructible {
    
    /// The type of input required to create a new instance.
    associatedtype InputType
    
    /// Creates a new instance of the conforming type asynchronously, using the specified input.
    ///
    /// - Parameter type: The input required to create the instance.
    /// - Returns: A new instance of the conforming type.
    /// - Throws: An error if the creation fails.
    static func create(type: InputType) async throws -> Constructible
}
