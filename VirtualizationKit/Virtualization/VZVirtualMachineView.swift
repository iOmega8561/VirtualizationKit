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
    
    /// Handles the `mouseUp` event, conditionally passing it to the superclass.
    ///
    /// - Parameter event: The mouse-up event to handle.
    ///
    /// If `disablesInputRedirection` is `true`, this method suppresses the event to prevent interaction; otherwise, it
    /// forwards the event to the superclass.
    override func mouseUp(with event: NSEvent) {
        disablesInputRedirection ? () : super.mouseUp(with: event)
    }
    
    /// Handles the `mouseDown` event, conditionally passing it to the superclass.
    ///
    /// - Parameter event: The mouse-down event to handle.
    ///
    /// If `disablesInputRedirection` is `true`, this method suppresses the event to prevent interaction; otherwise, it
    /// forwards the event to the superclass.
    override func mouseDown(with event: NSEvent) {
        disablesInputRedirection ? () : super.mouseDown(with: event)
    }
    
    /// Handles the `mouseMoved` event, conditionally passing it to the superclass.
    ///
    /// - Parameter event: The mouse-move event to handle.
    ///
    /// If `disablesInputRedirection` is `true`, this method suppresses the event to prevent interaction; otherwise, it
    /// forwards the event to the superclass.
    override func mouseMoved(with event: NSEvent) {
        disablesInputRedirection ? () : super.mouseMoved(with: event)
    }
    
    /// Handles the `mouseExited` event, conditionally passing it to the superclass.
    ///
    /// - Parameter event: The mouse-exit event to handle.
    ///
    /// If `disablesInputRedirection` is `true`, this method suppresses the event to prevent interaction; otherwise, it
    /// forwards the event to the superclass.
    override func mouseExited(with event: NSEvent) {
        disablesInputRedirection ? () : super.mouseExited(with: event)
    }
    
    /// Handles the `mouseDragged` event, conditionally passing it to the superclass.
    ///
    /// - Parameter event: The mouse-dragged event to handle.
    ///
    /// If `disablesInputRedirection` is `true`, this method suppresses the event to prevent interaction; otherwise, it
    /// forwards the event to the superclass.
    override func mouseDragged(with event: NSEvent) {
        disablesInputRedirection ? () : super.mouseDragged(with: event)
    }
    
    /// Handles the `mouseEntered` event, conditionally passing it to the superclass.
    ///
    /// - Parameter event: The mouse-entered event to handle.
    ///
    /// If `disablesInputRedirection` is `true`, this method suppresses the event to prevent interaction; otherwise, it
    /// forwards the event to the superclass.
    override func mouseEntered(with event: NSEvent) {
        disablesInputRedirection ? () : super.mouseEntered(with: event)
    }
    
    /// Handles hit testing, returning `nil` if `disablesInputRedirection` is `true`.
    ///
    /// - Parameter point: The location to test within the view's coordinate system.
    /// - Returns: The `NSView` at the specified point, or `nil` if `disablesInputRedirection` is `true`.
    ///
    /// If `disablesInputRedirection` is `true`, this method returns `nil` to ignore hits during preview.
    override func hitTest(_ point: NSPoint) -> NSView? {
        disablesInputRedirection ? nil : super.hitTest(point)
    }
}
