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
//  VZKitFramebuffer.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 15/10/24.
//

import AppKit

import Virtualization


/// A custom implementation of `VZVirtualMachineView`.
///
/// `VZKitFramebuffer` serves as a custom view for displaying virtual machine output, providing a replacement for
/// `VZVirtualMachineView` with added awareness of SwiftUI preview contexts. This class disables mouse interactions
/// when in preview mode, ensuring the view doesn't capture inputs that could interfere with development previews.
public final class VZKitFramebuffer: VZVirtualMachineView, VZKitPreviewable {
    
    /// Indicates if the view is in a SwiftUI preview context, controlling whether it should capture user interactions.
    ///
    /// When `true`, mouse events are ignored to prevent interaction during Xcode Previews.
    public var isPreviewContext: Bool = false
    
    /// Handles the `mouseUp` event, conditionally passing it to the superclass.
    ///
    /// - Parameter event: The mouse-up event to handle.
    ///
    /// If `isPreviewContext` is `true`, this method suppresses the event to prevent interaction; otherwise, it
    /// forwards the event to the superclass.
    public override func mouseUp(with event: NSEvent) {
        isPreviewContext ? () : super.mouseUp(with: event)
    }
    
    /// Handles the `mouseDown` event, conditionally passing it to the superclass.
    ///
    /// - Parameter event: The mouse-down event to handle.
    ///
    /// If `isPreviewContext` is `true`, this method suppresses the event to prevent interaction; otherwise, it
    /// forwards the event to the superclass.
    public override func mouseDown(with event: NSEvent) {
        isPreviewContext ? () : super.mouseDown(with: event)
    }
    
    /// Handles the `mouseMoved` event, conditionally passing it to the superclass.
    ///
    /// - Parameter event: The mouse-move event to handle.
    ///
    /// If `isPreviewContext` is `true`, this method suppresses the event to prevent interaction; otherwise, it
    /// forwards the event to the superclass.
    public override func mouseMoved(with event: NSEvent) {
        isPreviewContext ? () : super.mouseMoved(with: event)
    }
    
    /// Handles the `mouseExited` event, conditionally passing it to the superclass.
    ///
    /// - Parameter event: The mouse-exit event to handle.
    ///
    /// If `isPreviewContext` is `true`, this method suppresses the event to prevent interaction; otherwise, it
    /// forwards the event to the superclass.
    public override func mouseExited(with event: NSEvent) {
        isPreviewContext ? () : super.mouseExited(with: event)
    }
    
    /// Handles the `mouseDragged` event, conditionally passing it to the superclass.
    ///
    /// - Parameter event: The mouse-dragged event to handle.
    ///
    /// If `isPreviewContext` is `true`, this method suppresses the event to prevent interaction; otherwise, it
    /// forwards the event to the superclass.
    public override func mouseDragged(with event: NSEvent) {
        isPreviewContext ? () : super.mouseDragged(with: event)
    }
    
    /// Handles the `mouseEntered` event, conditionally passing it to the superclass.
    ///
    /// - Parameter event: The mouse-entered event to handle.
    ///
    /// If `isPreviewContext` is `true`, this method suppresses the event to prevent interaction; otherwise, it
    /// forwards the event to the superclass.
    public override func mouseEntered(with event: NSEvent) {
        isPreviewContext ? () : super.mouseEntered(with: event)
    }
    
    /// Handles hit testing, returning `nil` if `isPreviewContext` is `true`.
    ///
    /// - Parameter point: The location to test within the view's coordinate system.
    /// - Returns: The `NSView` at the specified point, or `nil` if `isPreviewContext` is `true`.
    ///
    /// If `isPreviewContext` is `true`, this method returns `nil` to ignore hits during preview.
    public override func hitTest(_ point: NSPoint) -> NSView? {
        isPreviewContext ? nil : super.hitTest(point)
    }
}
