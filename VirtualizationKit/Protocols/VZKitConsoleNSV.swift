//
//  VZKitConsoleNSV.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 15/10/24.
//

import AppKit

import Virtualization

/// This protocol sets a standard for our custom `VZVirtualMachineView` inherited class
/// The object should be aware if it's being used in a preview context, so it can apply the correct logic.
///
/// - Important: Object conforming to this protocol are also conforming to `NSView`, which is pinned to `@MainActor`
@MainActor public protocol VZKitConsoleNSV: VZVirtualMachineView {
    
    /// A boolean value to know it this representable will be used in preview contexts
    ///
    /// - Important: Pinned to rendering pipeline actor, which is `@MainActor`
    var isPreview: Bool { get }
    
    /// override of `NSView` method, should disable the event if isPreview == true
    ///
    /// - Important: Pinned to rendering pipeline actor, which is `@MainActor`
    func mouseUp(with event: NSEvent)
    
    /// override of `NSView` method, should disable the event if isPreview == true
    ///
    /// - Important: Pinned to rendering pipeline actor, which is `@MainActor`
    func mouseDown(with event: NSEvent)
    
    /// override of `NSView` method, should disable the event if isPreview == true
    ///
    /// - Important: Pinned to rendering pipeline actor, which is `@MainActor`
    func mouseMoved(with event: NSEvent)
    
    /// override of `NSView` method, should disable the event if isPreview == true
    ///
    /// - Important: Pinned to rendering pipeline actor, which is `@MainActor`
    func mouseExited(with event: NSEvent)
    
    /// override of `NSView` method, should disable the event if isPreview == true
    ///
    /// - Important: Pinned to rendering pipeline actor, which is `@MainActor`
    func mouseDragged(with event: NSEvent)
    
    /// override of `NSView` method, should disable the event if isPreview == true
    ///
    /// - Important: Pinned to rendering pipeline actor, which is `@MainActor`
    func mouseEntered(with event: NSEvent)
    
    /// override of `NSView` method, should return nil if isPreview == true
    ///
    /// - Important: Pinned to rendering pipeline actor, which is `@MainActor`
    func hitTest(_ point: NSPoint) -> NSView?
}
