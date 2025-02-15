//
//  VZVirtualMachineView.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 15/10/24.
//

import Virtualization

/// A specialized internal subclass of `Virtualization.VZVirtualMachineView` that encapsulates the display
/// functionality for `AppleVirtualMachine` within `VirtualizationKit`. This will be wrapped by other, public, Views or NSViews
/// to hide the low-level implementation details and specifically the `virtualMachine` property, so that it cannot be accessed.
///
/// Key Feature:
/// - **disablesInputRedirection**: When enabled, suppresses input events (such as mouse movement, entry, and
///   hit testing), effectively creating a non-interactive, preview-only display.
final class VZVirtualMachineView: Virtualization.VZVirtualMachineView, VZKitFramebufferNSView {
    
    /// Controls whether keyboard and mouse events are forwarded to the virtual machine.
    ///
    /// When set to `true`, input events are suppressed to prevent user interaction with the VM.
    var disablesInputRedirection: Bool = false
        
    /// Handles mouse movement events.
    ///
    /// Forwards the event to the superclass if input redirection is enabled; otherwise, ignores it.
    /// - Parameter event: The mouse movement event.
    override func mouseMoved(with event: NSEvent) {
        disablesInputRedirection ? () : super.mouseMoved(with: event)
    }
    
    /// Handles mouse entry events.
    ///
    /// Forwards the event to the superclass if input redirection is enabled; otherwise, ignores it.
    /// - Parameter event: The mouse entered event.
    override func mouseEntered(with event: NSEvent) {
        disablesInputRedirection ? () : super.mouseEntered(with: event)
    }
    
    /// Determines which view should receive a hit test event.
    ///
    /// Returns `nil` if input redirection is disabled, effectively preventing the view from responding to
    /// user interactions at the specified point. Otherwise, defers to the superclass's hit testing.
    /// - Parameter point: The location in the view’s coordinate system to test.
    /// - Returns: The appropriate `NSView` for the event, or `nil` if interactions are disabled.
    override func hitTest(_ point: NSPoint) -> NSView? {
        disablesInputRedirection ? nil : super.hitTest(point)
    }
}
