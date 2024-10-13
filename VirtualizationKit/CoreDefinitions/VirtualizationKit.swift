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
