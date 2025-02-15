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
