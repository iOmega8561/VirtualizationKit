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
//  OperatingSystem.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 16/05/24.
//

import SwiftUI

/// This enumeration has been created to define the possible operating systems that can be associated to a virtual machine.
/// Since Apple Virtualization Framework officially supports only Linux and macOS, only these two are included.
public enum OperatingSystem: VZKitOperatingSystem {
    case linux
    case macos
    
    public var image: Image {
        switch self {
        case .linux:
            return Image("tux")
        case .macos:
            return Image(systemName: "apple.logo")
        }
    }
    
    public var label: Text {
        switch self {
        case .linux:
            return Text(verbatim: "Linux")
        case .macos:
            return Text(verbatim: "macOS")
        }
    }
}
