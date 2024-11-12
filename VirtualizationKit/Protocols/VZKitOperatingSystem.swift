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
//  VZKitOperatingSystem.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 16/05/24.
//

import SwiftUI

import UniformTypeIdentifiers

/// VZKitOperatingSystem protocol
///
/// @brief
///    This protocol defines how a Virtual Machine OS Type should be implemented in this application.
///    `VZKitOperatingSystem` helps us define two crucial methods that will significally reduce
///    the bulk of `SwiftUI` statements. We can simply get the assets of the given OS by callin these methods.
public protocol VZKitOperatingSystem: Codable, Hashable, CaseIterable, Sendable {
    
    associatedtype VersionType: VZKitOperatingSystemVersion
    
    var image: Image { get }
    
    var label: Text { get }
    
    var fileType: UTType { get }
    
    var version: VersionType? { get }
}
