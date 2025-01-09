//
//  VZKitConsoleView.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 12/10/24.
//

import SwiftUI

import Virtualization

/// A SwiftUI-compatible wrapper for an AppKit-based virtual machine console view.
///
/// `VZKitConsoleView` is a wrapper around an AppKit `NSView` that provides a graphical console for a virtual machine.
/// It conforms to `VZKitPreviewable` and can be used as a SwiftUI view through `NSViewRepresentable`.
/// This structure is designed to configure and present the virtual machine's display within a SwiftUI application.
///
/// # Overview
/// This wrapper manages the following properties for the virtual machine console:
/// - `virtualMachine`: The virtual machine instance for display output.
/// - `automaticallyReconfiguresDisplay`: Determines if the console should adjust the display configuration based on window size.
/// - `capturesSystemKeys`: Determines if the console should capture system-wide key combinations.
///
/// `VZKitConsoleView` is intended to be wrapped by a `ConsoleView` for direct use in SwiftUI layouts. The view is
/// configurable based on whether it is running in a preview context, allowing for a customized experience in development
/// previews.
///
/// - Note: `VZKitConsoleView` should only be used within a SwiftUI context and is not designed for standalone usage.
///
/// - Parameters:
///   - Template: A type conforming to `VZKitTemplate`, which provides the necessary configuration for the virtual machine.
public struct VZKitConsoleView<Template: VZKitTemplate>: NSViewRepresentable, VZKitPreviewable {
    
    /// Indicates if the view is used in a preview context.
    ///
    /// This boolean value helps determine if the representable should adjust its configuration for Xcode's SwiftUI Preview.
    public let isPreviewContext: Bool
    
    /// A flag indicating whether the console view should automatically reconfigure the display to match the window size.
    ///
    /// Setting this to `true` allows the virtual machine's display to automatically adapt to the containing window.
    public let automaticallyReconfiguresDisplay: Bool
    
    /// A flag indicating whether the console should capture system key commands.
    ///
    /// If set to `true`, the guest VM can capture key bindings from the host system.
    public let capturesSystemKeys: Bool
    
    /// The virtual machine instance to be displayed in the console view.
    ///
    /// This instance provides the console with access to the VM's display and state. It is only available when unwrapped.
    private let vzVirtualMachine: VZVirtualMachine?
    
    /// Creates and configures the `NSView` for this console view.
    ///
    /// This method is part of the standard `NSViewRepresentable` protocol and initializes the
    /// `VZKitFramebuffer` instance, binding the appropriate virtual machine and context state.
    ///
    /// - Parameter context: The context provided by `NSViewRepresentable`, which manages lifecycle and coordination.
    /// - Returns: A configured instance of `VZKitFramebuffer` displaying the virtual machine's output.
    public func makeNSView(context: Context) -> VZKitFramebuffer {
        let vmView = VZKitFramebuffer()
        vmView.virtualMachine = vzVirtualMachine
        vmView.isPreviewContext = isPreviewContext
        return vmView
    }
    
    /// Updates the console view with new state or configuration changes.
    ///
    /// This method is called automatically when SwiftUI detects a state change, and it ensures that properties
    /// such as `automaticallyReconfiguresDisplay` and `capturesSystemKeys`
    /// are synchronized with the `VZKitFramebuffer`.
    ///
    /// - Parameters:
    ///   - vmView: The existing `VZKitFramebuffer` view instance to update.
    ///   - context: The context provided by `NSViewRepresentable` for managing state and interactions.
    public func updateNSView(_ vmView: VZKitFramebuffer, context: Context) {
        vmView.virtualMachine = vzVirtualMachine
        vmView.automaticallyReconfiguresDisplay = automaticallyReconfiguresDisplay
        vmView.capturesSystemKeys = capturesSystemKeys
    }
    
    /// Initializes a console view for use in a non-preview context.
    ///
    /// This initializer should be used when the console view is part of a live app instance.
    ///
    /// - Parameters:
    ///   - machine: A virtual machine instance of type `VirtualMachine<Template>` to display in the console.
    ///   - automaticallyReconfiguresDisplay: Specifies if the console view should auto-resize to match window dimensions.
    ///   - capturesSystemKeys: Specifies if the console view should capture system-wide key commands.
    public init(
        machine: VirtualMachine<Template>,
        automaticallyReconfiguresDisplay: Bool,
        capturesSystemKeys: Bool
    ) {
        self.vzVirtualMachine = machine.vzVirtualMachine
        self.isPreviewContext = false
        self.automaticallyReconfiguresDisplay = automaticallyReconfiguresDisplay
        self.capturesSystemKeys = capturesSystemKeys
    }
    
    /// Initializes a console view for use in a preview context.
    ///
    /// This initializer is designed for SwiftUI Preview configurations and allows disabling automatic display and key capture settings.
    ///
    /// - Parameters:
    ///   - machine: A virtual machine instance of type `VirtualMachine<Template>` to display in the console.
    ///   - isPreviewContext: Boolean indicating whether this instance is in a preview environment (defaults to `true`).
    public init(machine: VirtualMachine<Template>, isPreviewContext: Bool = true) {
        self.vzVirtualMachine = machine.vzVirtualMachine
        self.isPreviewContext = isPreviewContext
        self.automaticallyReconfiguresDisplay = false
        self.capturesSystemKeys = false
    }
}
