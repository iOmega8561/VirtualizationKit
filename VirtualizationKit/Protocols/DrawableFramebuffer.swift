//
//  DrawableFramebuffer.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 12/10/24.
//

import SwiftUI

/// A protocol defining the required properties for a UI element that displays a virtual machine's
/// framebuffer and responds to display-related updates.
///
/// `DrawableFramebuffer` is specifically intended for use with drawable contexts such as SwiftUI
/// `View` types or `NSView` subclasses in AppKit. Conforming types should handle the display of
/// the guest operating system within the host application, optionally forwarding keyboard and mouse
/// events. This protocol is pinned to the main actor to ensure all UI updates occur on the main thread.
///
/// - Important: This protocol is not compiler-enforced to accept only `View` or `NSView`
///   types, its design targets these two categories of UI elements. Don't conform to this protocol
///   directly but use the specific ones `FramebufferView` and `FramebufferNSView`.
@MainActor public protocol DrawableFramebuffer {
    
    /// A Boolean value indicating whether keyboard and mouse events should be blocked from the guest.
    ///
    /// When `true`, the VM will not receive input events from mouse or keyboard interactions,
    /// effectively rendering the view as a “preview-only” display. When `false`, user input
    /// is forwarded to the VM.
    var disablesInputRedirection: Bool { get }
    
    /// A Boolean value indicating whether the virtual display should automatically resize, adapting to its window.
    ///
    /// When `true`, the virtual machine’s display automatically resizes to match the container’s
    /// dimensions, providing a more seamless viewing experience. When `false`, the VM’s
    /// display resolution and window size remain static.
    var automaticallyReconfiguresDisplay: Bool { get }
    
    /// A Boolean value indicating whether or not system hotkeys should be captured by the guest.
    ///
    /// When `true`, certain system-level key combinations (such as Command-Tab) are captured by
    /// the virtual machine instead of the host operating system. This can be useful when you want
    /// the guest OS to have exclusive control over key sequences.
    var capturesSystemKeys: Bool { get }
}

/// A protocol for SwiftUI views that display a virtual machine’s framebuffer.
@MainActor
public protocol FramebufferView: DrawableFramebuffer, View { }

/// A protocol for AppKit views that display a virtual machine’s framebuffer.
@MainActor
public protocol FramebufferNSView: DrawableFramebuffer where Self: NSView { }
