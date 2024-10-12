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
            return machine.wrappedValue
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
    
    /// This `Binding` is needed to update the boolean value `automaticallyReconfiguresDisplay` of `VZVirtualMachineView`
    /// during an update of our `NSViewController`. When it's set to true, the screen of the VM adapts to the window.
    public var isScreenAdaptive: Binding<Bool>
    
    /// This `Binding` is needed to update the boolean value `capturesSystemKeys` of `VZVirtualMachineView`
    /// during an update of our `NSViewController`. When it's set to true, the guest VM captures keybinds from the host.
    public var areKeysCaptured: Binding<Bool>
    
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
        return nsViewController
    }
    
    /// Implementation of standard method `updateNSViewController`.
    /// Mainly ensures that the correct updates happen on `vmView` childs.
    public func updateNSViewController(_ nsViewController: ConsoleNSVC, context: Context) {
        
        if nsViewController.vmView.virtualMachine != unwrappedResult {
            nsViewController.vmView.virtualMachine = unwrappedResult
        }
        
        nsViewController.vmView.automaticallyReconfiguresDisplay = isScreenAdaptive.wrappedValue
        nsViewController.vmView.capturesSystemKeys = areKeysCaptured.wrappedValue
    }
    
    public init(
        result: VZKitResult<TemplateType>?,
        isScreenAdaptive: Binding<Bool>,
        areKeysCaptured: Binding<Bool>)
    {
        self.result = result
        self.isScreenAdaptive = isScreenAdaptive
        self.areKeysCaptured = areKeysCaptured
    }
}
