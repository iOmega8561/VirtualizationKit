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

protocol VZKitSpecializedConstructible: VZKitConstructible {
        
    associatedtype InputType
    
    /// This is the standard factory method for any `VZKitSpecializedConstructible` conforming class.
    /// It should create and return the appropriate device attachment ready to be used, based on the input type.
    ///
    /// - Parameters:
    ///   - type: The network configuration of choice
    static func create(type: InputType) async throws -> Constructible
}
