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

/// VirtHandlerMachineOS protocol
///
/// @brief
///    This protocol defines how a Virtual Machine OS Type should be implemented in this application.
///    `VirtHandlerMachineOS` helps us define two crucial methods that will significally reduce
///    the bulk of `SwiftUI` statements. We can simply get the assets of the given OS by callin these methods.
public protocol VZKitOperatingSystem: Codable, Hashable, CaseIterable, Sendable {
    
    var image: Image { get }
    
    var label: Text { get }
}
