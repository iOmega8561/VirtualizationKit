//
//  VZKitGenericConstructible.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 09/01/25.
//

protocol VZKitGenericConstructible: VZKitConstructible {
        
    static func create() async throws -> Constructible
}
