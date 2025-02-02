//
//  FramebufferView.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 12/10/24.
//

import SwiftUI

import Virtualization

/// A SwiftUI-compatible wrapper for the virtual machine display.
///
/// `FramebufferView` is a SwiftUI representable view (conforms to `NSViewRepresentable`) that can be
/// used to access the virtual machine display and interact with it using mouse and keyboard. The view is configurable,
/// allowing to set specific properties that will modify the behaviour of the virtual machine display
///
/// This wrapper manages the following properties for the virtual machine console:
/// - `VirtualMachine`: The virtual machine instance for display output.
/// - `automaticallyReconfiguresDisplay`: Determines if the console should adjust the display configuration based on window size.
/// - `capturesSystemKeys`: Determines if the console should capture system-wide key combinations.
/// - `disablesInputRedirection`: Determines if the view should forward mouse and keyboard input to the virtual machine.
public struct FramebufferView: NSViewRepresentable, VZKitPreviewable {
    
    /// A flag indicating whether the console view should automatically reconfigure the display to match the window size.
    ///
    /// Setting this to `true` allows the virtual machine's display to automatically adapt to the containing window.
    public let automaticallyReconfiguresDisplay: Bool
    
    /// A flag indicating whether the console should capture system key commands.
    ///
    /// If set to `true`, the guest VM can capture key bindings from the host system.
    public let capturesSystemKeys: Bool
    
    /// A boolean value that determines whether or not the keyboard and mouse controls should be forwarded.
    ///
    /// When `true`, events are ignored to prevent interaction with the virtual machine
    public let disablesInputRedirection: Bool
    
    /// The virtual machine instance to be displayed in the console view.
    ///
    /// This instance provides the console with access to the VM's display and state.
    private let vzVirtualMachine: VZVirtualMachine
    
    /// Creates and configures the `NSView` for this console view.
    ///
    /// This method is part of the standard `NSViewRepresentable` protocol and initializes the
    /// `FramebufferNSView` instance, binding the appropriate virtual machine and context state.
    ///
    /// - Parameter context: The context provided by `NSViewRepresentable`, which manages lifecycle and coordination.
    /// - Returns: A configured instance of `FramebufferNSView` displaying the virtual machine's output.
    public func makeNSView(context: Context) -> FramebufferNSView {
        let vmView = FramebufferNSView()
        vmView.virtualMachine = vzVirtualMachine
        vmView.disablesInputRedirection = disablesInputRedirection
        return vmView
    }
    
    /// Updates the console view with new state or configuration changes.
    ///
    /// This method is called automatically when SwiftUI detects a state change, and it ensures that properties
    /// such as `automaticallyReconfiguresDisplay` and `capturesSystemKeys`
    /// are synchronized with the `FramebufferNSView`.
    ///
    /// - Parameters:
    ///   - vmView: The existing `FramebufferNSView` view instance to update.
    ///   - context: The context provided by `NSViewRepresentable` for managing state and interactions.
    public func updateNSView(_ vmView: FramebufferNSView, context: Context) {
        vmView.virtualMachine = vzVirtualMachine
        vmView.automaticallyReconfiguresDisplay = automaticallyReconfiguresDisplay
        vmView.capturesSystemKeys = capturesSystemKeys
        vmView.disablesInputRedirection = disablesInputRedirection
    }
    
    
    /// Creates an instance of `FramebufferView` ready to be used in a SwiftUI context
    ///
    /// # Generics
    /// This initializer requires `Template` to conform to `VZKitTemplate`. It is also required by `VirtualMachine`
    ///
    /// - Parameters:
    ///   - virtualMachine: A virtual machine instance of type `VirtualMachine<Template>` to display in the console.
    ///   - automaticallyReconfiguresDisplay: Specifies if the console view should auto-resize to match window dimensions. Defaults to `false`
    ///   - capturesSystemKeys: Specifies if the console view should capture system-wide key commands. Defaults to `false`
    ///   - disablesInputRedirection: Determines if the view should forward mouse and keyboard input to the virtual machine. Defaults to `true`
    public init<Template: VZKitTemplate>(
        virtualMachine: VirtualMachine<Template>,
        automaticallyReconfiguresDisplay: Bool = false,
        capturesSystemKeys: Bool = false,
        disablesInputRedirection: Bool = true
    ) {
        self.vzVirtualMachine = virtualMachine.vzVirtualMachine
        self.automaticallyReconfiguresDisplay = automaticallyReconfiguresDisplay
        self.capturesSystemKeys = capturesSystemKeys
        self.disablesInputRedirection = disablesInputRedirection
    }
    
    /// Creates an instance of `FramebufferView` that works with a `VZVirtualMachine` object from `Virtualization.framework`
    /// This init allows for inter-operability with custom `Virtualization.framework` configurations and / or objects.
    ///
    /// - Parameters:
    ///   - virtualMachine: A virtual machine instance of type `VZVirtualMachine` to display in the console.
    ///   - automaticallyReconfiguresDisplay: Specifies if the console view should auto-resize to match window dimensions.  Defaults to `false`
    ///   - capturesSystemKeys: Specifies if the console view should capture system-wide key commands. Defaults to `false`
    ///   - disablesInputRedirection: Determines if the view should forward mouse and keyboard input to the virtual machine. Defaults to `true`
    public init(
        virtualMachine: VZVirtualMachine,
        automaticallyReconfiguresDisplay: Bool = false,
        capturesSystemKeys: Bool = false,
        disablesInputRedirection: Bool = true
    ) {
        self.vzVirtualMachine = virtualMachine
        self.automaticallyReconfiguresDisplay = automaticallyReconfiguresDisplay
        self.capturesSystemKeys = capturesSystemKeys
        self.disablesInputRedirection = disablesInputRedirection
    }
}
