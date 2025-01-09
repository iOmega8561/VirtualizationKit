//
//  VZKitConstructible.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 09/01/25.
//

import Virtualization

/// A protocol that defines a constructible type.
///
/// Types conforming to `VZKitConstructible` can specify an associated type
/// that defaults to `Self`, enabling generic construction patterns.
protocol VZKitConstructible {
    
    /// The type of the object to be constructed.
    associatedtype Constructible = Self
}
