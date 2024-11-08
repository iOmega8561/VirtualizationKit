//
//  VZKitViewController 2.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 12/10/24.
//


//
//  VZKitConsoleNSVCR.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 12/10/24.
//

import SwiftUI

import Virtualization

/// The `VZKitConsoleNSVCR` protocol defines a common interface for `NSViewControllerRepresentable` to be used in this framework.
///
/// @brief
///    This should give birth to `SwiftUI` wrappers for our `AppKit` console view controller component.
///    During the view controller update, this UI element will set the right values for the following keys:
///    virtualMachine, automaticallyReconfiguresDisplay, capturesSystemKeys
protocol VZKitConsoleNSVCR: NSViewControllerRepresentable {
    
    associatedtype CoordinatorType: NSObject
    
    associatedtype ControllerType: VZKitConsoleNSVC
    
    associatedtype TemplateType: VZKitTemplate
    
    /// `VZKitResult` to be unwrapped, in order to attach the virtual machine to a `NSViewController`
    var result: VZKitResult<TemplateType>? { get }
    
    /// A boolean value to know it this representable will be used in preview contexts
    var isPreview: Bool { get }
    
    /// This `Bool` is needed to update the boolean value `automaticallyReconfiguresDisplay` of `VZVirtualMachineView`
    /// during an update of our `NSViewController`. When it's set to true, the screen of the VM adapts to the window.
    var isScreenAdaptive: Bool { get }
    
    /// This `Bool` is needed to update the boolean value `capturesSystemKeys` of `VZVirtualMachineView`
    /// during an update of our `NSViewController`. When it's set to true, the guest VM captures keybinds from the host.
    var areKeysCaptured: Bool { get }
    
    /// Implementation of standard method `makeCoordinator`.
    ///
    /// - Important: Rendering queue, pinned to @MainActor for thread-safe access.
    @MainActor func makeCoordinator() -> CoordinatorType
    
    /// Implementation of standard method `makeNSViewController`.
    ///
    /// - Important: Rendering queue, pinned to @MainActor for thread-safe access.
    @MainActor func makeNSViewController(context: Context) -> ControllerType
    
    /// Implementation of standard method `updateNSViewController`.
    /// 
    /// - Important: Rendering queue, pinned to @MainActor for thread-safe access.
    @MainActor func updateNSViewController(_ nsViewController: ControllerType, context: Context)
}
