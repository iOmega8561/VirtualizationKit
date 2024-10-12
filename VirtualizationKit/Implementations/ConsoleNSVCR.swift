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
    
    public let result: VZKitResult<TemplateType>?
    
    public var isScreenAdaptive: Binding<Bool>
    
    public var areKeysCaptured: Binding<Bool>
    
    private var unwrappedResult: VZVirtualMachine? {
        switch result {
        case .success(let machine):
            return machine.wrappedValue
        default:
            return nil
        }
    }
    
    public class Coordinator : NSObject {
        var parent: ConsoleNSVCR
        
        init(_ parent: ConsoleNSVCR) {
            self.parent = parent
        }
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    /// Implementation of standard method `makeNSViewController`.
    /// Creates the `ViewController` and binds the correct virtualMachine to it.
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
