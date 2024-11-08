//
//  ConsoleNSV.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 15/10/24.
//

import AppKit

import Virtualization

/// Custom implementaton of `VZVirtualMachineView`, with conformation to `VZKitConsoleNSV`.
/// This will be used in this framework to serve as a better replacement for `VZVirtualMachineView`, to have
/// awareness of preview context, in order to not capture mouse inputs. Since both the protocol and the class
/// expect inheritance from `NSView`, this class is pinned to `@MainActor`.
final class ConsoleNSV: VZVirtualMachineView, VZKitConsoleNSV {
    
    /// A boolean value to know it this representable will be used in preview contexts
    ///
    /// - Important: Pinned to rendering pipeline actor, which is `@MainActor`
    public var isPreview: Bool = false
    
    /// override of `NSView` method, should disable the event if isPreview == true
    ///
    /// - Important: Pinned to rendering pipeline actor, which is `@MainActor`
    public override func mouseUp(with event: NSEvent) {
        if !self.isPreview { super.mouseUp(with: event) }
    }
    
    /// override of `NSView` method, should disable the event if isPreview == true
    ///
    /// - Important: Pinned to rendering pipeline actor, which is `@MainActor`
    public override func mouseDown(with event: NSEvent) {
        if !self.isPreview { super.mouseDown(with: event) }
    }
    
    /// override of `NSView` method, should disable the event if isPreview == true
    ///
    /// - Important: Pinned to rendering pipeline actor, which is `@MainActor`
    public override func mouseMoved(with event: NSEvent) {
        if !self.isPreview { super.mouseMoved(with: event) }
    }
    
    /// override of `NSView` method, should disable the event if isPreview == true
    ///
    /// - Important: Pinned to rendering pipeline actor, which is `@MainActor`
    public override func mouseExited(with event: NSEvent) {
        if !self.isPreview { super.mouseExited(with: event) }
    }
    
    /// override of `NSView` method, should disable the event if isPreview == true
    ///
    /// - Important: Pinned to rendering pipeline actor, which is `@MainActor`
    public override func mouseDragged(with event: NSEvent) {
        if !self.isPreview { super.mouseDragged(with: event) }
    }
    
    /// override of `NSView` method, should disable the event if isPreview == true
    ///
    /// - Important: Pinned to rendering pipeline actor, which is `@MainActor`
    public override func mouseEntered(with event: NSEvent) {
        if !self.isPreview { super.mouseEntered(with: event) }
    }
    
    /// override of `NSView` method, should disable the event if isPreview == true
    ///
    /// - Important: Pinned to rendering pipeline actor, which is `@MainActor`
    public override func hitTest(_ point: NSPoint) -> NSView? {
        if !self.isPreview { return super.hitTest(point) }; return nil
    }
}
