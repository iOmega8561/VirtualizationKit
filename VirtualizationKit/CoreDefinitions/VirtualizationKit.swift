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
//  VirtualizationKit.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 13/10/24.
//

import Foundation

public final class _VirtualizationKit: Sendable {
    
    public let version: String = "1.0"
    
    public let bundle: Bundle? = .init(identifier: "giusepperocco.VirtualizationKit")
    
    @MainActor private var _bundlePath: String = NSHomeDirectory() + "/VirtualizationKit.bundle/"
    
    @MainActor public var bundlePath: String { return _bundlePath }
    
    @MainActor public func setBundlePath(_ bundlePath: String) {
        _bundlePath = bundlePath
    }
    
    fileprivate init() {}
}

public let VirtualizationKit: _VirtualizationKit = .init()
