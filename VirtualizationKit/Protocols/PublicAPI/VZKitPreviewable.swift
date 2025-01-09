//
//  VZKitViewController 2.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 12/10/24.
//


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
//  VZKitPreviewable.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 12/10/24.
//

import Foundation

/// The `VZKitPreviewable` protocol defines a common interface to create representable objects with
/// the most common available frameworks for macOS (SwiftUI mainly and AppKit) that are aware of possible preview contexts.
/// During state updates, the UI element that uses this inferface will have to set the right values for the following keys:
/// virtualMachine, automaticallyReconfiguresDisplay, capturesSystemKeys
///
/// - Note: The terminology "Preview Context" refers to a specific use-case in virtualization softwares, specifically
/// Virtual Machine managers, that allows to view the content that is currently displayed by the VM on its virtual screen,
/// without having the possibility to interact with it (no feedback from mouse and keyboard).
///
/// - Important: This interface expects the conforming types to be UI elements, like NSView, NSViewRepresentable or SwiftUI's View.
/// These components are processed on the main thread, therefore this protocol expects this behaviour too.
@MainActor public protocol VZKitPreviewable {
    
    /// A boolean value to know it this representable will be used in preview contexts
    var isPreviewContext: Bool { get }
    
    /// This `Bool` is needed to update the boolean value `automaticallyReconfiguresDisplay` of `VZVirtualMachineView`
    /// during a state update of the UI element. When it's set to true, the screen of the VM adapts to the window.
    var automaticallyReconfiguresDisplay: Bool { get }
    
    /// This `Bool` is needed to update the boolean value `capturesSystemKeys` of `VZVirtualMachineView`
    /// during a state update of the UI element. When it's set to true, the guest VM captures keybinds from the host.
    var capturesSystemKeys: Bool { get }
}
