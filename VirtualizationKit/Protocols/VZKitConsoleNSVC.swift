//
//  VZKitConsoleNSVC.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 12/10/24.
//

import SwiftUI

import Virtualization

/// The `VZKitConsoleNSVC` protocol defines an interface to be used by our custom `NSViewController`.
/// An object conforming to this protocol will be wrapped up by a `NSViewControllerRepresentable`.
public protocol VZKitConsoleNSVC: NSViewController {
    
    /// A reference to an instance of `VZVirtualMachineView` that will be rendered eventually
    var vmView: VZVirtualMachineView { get }
    
    /// override of `NSViewController` behaviour, should create the `NSView` object
    ///
    /// - Important: Rendering queue, pinned to @MainActor for thread-safe access.
    @MainActor func loadView()
    
    /// override of `NSViewController` behaviour, should push `vmView` to rendering
    ///
    /// - Important: Rendering queue, pinned to @MainActor for thread-safe access.
    @MainActor func viewDidLoad()
}
