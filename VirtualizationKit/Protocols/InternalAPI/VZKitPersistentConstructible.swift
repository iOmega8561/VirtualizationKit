//
//  VZKitPersistentConstructible.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 09/01/25.
//

/// A protocol that extends `VZKitConstructible` for storage-based construction.
///
/// Types conforming to `VZKitPersistentConstructible` provide a static factory method
/// that supports creating instances based on a file location and input type.
protocol VZKitPersistentConstructible: VZKitConstructible {
    
    /// The type of input required to create a new instance.
    associatedtype InputType
    
    /// Creates a new instance of the conforming type at the specified location, using the specified input.
    ///
    /// - Parameters:
    ///   - url: The file system URL where the instance should be created.
    ///   - type: The input required to create the instance.
    /// - Returns: A new instance of the conforming type.
    /// - Throws: An error if the creation fails.
    static func create(at url: URL, type: InputType) throws -> Constructible
}
