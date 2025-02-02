//
//  FramebufferNSView.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 15/10/24.
//

import Virtualization

/// A custom subclass of `VZVirtualMachineView` for AppKit applications.
///
/// `FramebufferNSView` functions similarly to `FramebufferView`, but is designed specifically for AppKit-based applications.
/// It serves as a direct replacement for `VZVirtualMachineView`, displaying the virtual machine screen.
///
/// Key features:
/// - `disablesInputRedirection`: Prevents forwarding of input events (mouse movement, entry, and hit testing) when enabled.
/// - `init(virtualMachine:)`: Initializes an instance of `FramebufferNSView` using a `VirtualMachine` object from VirtualizationKit.
public final class FramebufferNSView: VZVirtualMachineView, VZKitPreviewable {
    
    /// Determines whether keyboard and mouse events should be ignored.
    ///
    /// When `true`, input events are suppressed to prevent interaction with the virtual machine.
    public var disablesInputRedirection: Bool = false
        
    /// Handles mouse movement events.
    ///
    /// Suppresses the event if `disablesInputRedirection` is `true`; otherwise, forwards it to the superclass.
    /// - Parameter event: The mouse-move event.
    public override func mouseMoved(with event: NSEvent) {
        disablesInputRedirection ? () : super.mouseMoved(with: event)
    }
    
    /// Handles mouse entry events.
    ///
    /// Suppresses the event if `disablesInputRedirection` is `true`; otherwise, forwards it to the superclass.
    /// - Parameter event: The mouse-entered event.
    public override func mouseEntered(with event: NSEvent) {
        disablesInputRedirection ? () : super.mouseEntered(with: event)
    }
    
    /// Performs hit testing.
    ///
    /// Returns `nil` if `disablesInputRedirection` is `true`, otherwise defers to the superclass.
    /// - Parameter point: The location to test in the view's coordinate system.
    /// - Returns: The `NSView` at the specified point, or `nil` if interaction is disabled.
    public override func hitTest(_ point: NSPoint) -> NSView? {
        disablesInputRedirection ? nil : super.hitTest(point)
    }
    
    /// Initializes the view with a `VirtualMachine` instance.
    ///
    /// - Parameter virtualMachine: The `VirtualMachine` instance used to configure the view.
    public convenience init<Template: VZKitTemplate>(virtualMachine: VirtualMachine<Template>) {
        self.init()
        self.virtualMachine = virtualMachine.vzVirtualMachine
    }
}
