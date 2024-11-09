//
//  ViewControllerRepresentable.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 12/10/24.
//

import SwiftUI

import Virtualization

/// The virtual machine console view controller representable
///
/// @brief
///    This is the `SwiftUI` wrapper for our `AppKit` console view controller component.
///    Itself will be wrapped by `ConsoleView`, which is a proper SwiftUI `View` struct.
///    During the view controller update, this UI element will set the right values for the following keys:
///    virtualMachine, automaticallyReconfiguresDisplay, capturesSystemKeys
public struct ConsoleNSVCR<TemplateType: VZKitTemplate>: NSViewControllerRepresentable, VZKitConsoleNSVCR {
    
    /// A simple computed property to unwrap the `VZVirtualMachine` object from the optional `VZKitResult`
    /// Very useful to save a few lines of code while implementing `NSViewControllerRepresentable` stubs
    private var unwrappedResult: VZVirtualMachine? {
        switch result {
        case .success(let machine):
            return machine.vzVirtualMachine
        default:
            return nil
        }
    }
    
    /// An extremely simplified `Coordinator` type with no logic whatsoever.
    /// What it does is simply set the caller object as it's parent
    public class Coordinator : NSObject {
        var parent: ConsoleNSVCR
        
        init(_ parent: ConsoleNSVCR) {
            self.parent = parent
        }
    }
    
    /// `VZKitResult` to be unwrapped, in order to attach the virtual machine to a `NSViewController`
    public let result: VZKitResult<TemplateType>?
    
    /// A boolean value to know it this representable will be used in preview contexts
    public let isPreview: Bool
    
    /// This `Bool` is needed to update the boolean value `automaticallyReconfiguresDisplay` of `VZVirtualMachineView`
    /// during an update of our `NSViewController`. When it's set to true, the screen of the VM adapts to the window.
    public let isScreenAdaptive: Bool
    
    /// This `Bool` is needed to update the boolean value `capturesSystemKeys` of `VZVirtualMachineView`
    /// during an update of our `NSViewController`. When it's set to true, the guest VM captures keybinds from the host.
    public let areKeysCaptured: Bool
    
    /// Implementation of standard method `makeCoordinator`.
    /// Literally just creates the coordinator. It's actually useless (the coordinator has no use here).
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    /// Implementation of standard method `makeNSViewController`.
    /// Creates the `NSViewController` and binds the correct virtualMachine to it.
    public func makeNSViewController(context: Context) -> ConsoleNSVC {
        let nsViewController = ConsoleNSVC()
        nsViewController.vmView.virtualMachine = unwrappedResult
        nsViewController.vmView.isPreview = isPreview
        return nsViewController
    }
    
    /// Implementation of standard method `updateNSViewController`.
    /// Mainly ensures that the correct updates happen on `vmView` childs.
    public func updateNSViewController(_ nsViewController: ConsoleNSVC, context: Context) {
        
        // This check is needed because in some context the same object may be used
        // to operate on different virtual machines. Here we make sure it's the right one
        if nsViewController.vmView.virtualMachine != unwrappedResult {
            nsViewController.vmView.virtualMachine = unwrappedResult
        }
        
        nsViewController.vmView.automaticallyReconfiguresDisplay = isScreenAdaptive
        nsViewController.vmView.capturesSystemKeys = areKeysCaptured
    }
    
    /// This initializer is to be used outside of Preview contexts
    ///
    /// - Parameters:
    ///   - result: the VZKitResult to be unwrapped in order to retrieve the VZVirtualMachine reference
    ///   - isScreenAdaptive: A boolean stating if the virtual machine view should automatically reconfigure the display
    ///   - areKeysCaptured: A boolean stating if the virtual machine view should capture system hotkeys
    public init(
        result: VZKitResult<TemplateType>?,
        isScreenAdaptive: Bool,
        areKeysCaptured: Bool
    ) {
        self.result = result
        self.isPreview = false
        self.isScreenAdaptive = isScreenAdaptive
        self.areKeysCaptured = areKeysCaptured
    }
    
    /// This initializer is to be used in Preview context
    ///
    /// - Parameters:
    ///   - result: the VZKitResult to be unwrapped in order to retrieve the VZVirtualMachine reference
    ///   - isPreview: the boolean stating that this will be used i a preview context
    public init(result: VZKitResult<TemplateType>?, isPreview: Bool = true) {
        self.result = result
        self.isPreview = isPreview
        self.isScreenAdaptive = false
        self.areKeysCaptured = false
    }
}
