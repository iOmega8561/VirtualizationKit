//
//  VZKitGenericConstructible.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 09/01/25.
//

/// A protocol that extends `VZKitConstructible` to support asynchronous creation.
///
/// Types conforming to `VZKitGenericConstructible` provide a static factory method
/// for creating instances asynchronously, which may throw errors during construction.
protocol VZKitGenericConstructible: VZKitConstructible {
    
    /// Creates a new instance of the conforming type asynchronously.
    ///
    /// - Returns: A new instance of the conforming type.
    /// - Throws: An error if the creation fails.
    static func create() async throws -> Constructible
}
