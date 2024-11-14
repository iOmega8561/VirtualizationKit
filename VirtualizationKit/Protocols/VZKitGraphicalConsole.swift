//
//  VZKitViewController 2.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 12/10/24.
//


//
//  VZKitGraphicalConsole.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 12/10/24.
//

import SwiftUI

import Virtualization

/// The `VZKitGraphicalConsole` protocol defines a common interface for `NSViewControllerRepresentable` to be used in this framework.
///
/// @brief
///    This should give birth to `SwiftUI` wrappers for our `AppKit` console view controller component.
///    During the view controller update, this UI element will set the right values for the following keys:
///    virtualMachine, automaticallyReconfiguresDisplay, capturesSystemKeys
@MainActor protocol VZKitGraphicalConsole: NSViewRepresentable {
    
    /// A boolean value to know it this representable will be used in preview contexts
    var isPreviewContext: Bool { get }
    
    /// This `Bool` is needed to update the boolean value `automaticallyReconfiguresDisplay` of `VZVirtualMachineView`
    /// during an update of our `NSViewController`. When it's set to true, the screen of the VM adapts to the window.
    var automaticallyReconfiguresDisplay: Bool { get }
    
    /// This `Bool` is needed to update the boolean value `capturesSystemKeys` of `VZVirtualMachineView`
    /// during an update of our `NSViewController`. When it's set to true, the guest VM captures keybinds from the host.
    var capturesSystemKeys: Bool { get }
}
