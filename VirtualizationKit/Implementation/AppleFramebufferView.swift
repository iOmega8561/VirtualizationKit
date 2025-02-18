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
//  AppleFramebufferView.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 12/10/24.
//

import SwiftUI

import Virtualization

/// A SwiftUI-compatible wrapper that encapsulates the virtual machine display for use in your app’s UI.
///
/// `AppleFramebufferView` conforms to `NSViewRepresentable` and internally uses a specialized
/// subclass of `VZVirtualMachineView` to render the virtual machine's output. This design
/// hides the underlying implementation details, exposing only the necessary configuration properties
/// for integration in SwiftUI contexts.
///
/// The view provides configurable options to control the behavior of the VM display:
/// - **automaticallyReconfiguresDisplay**: When enabled, the VM display automatically adjusts to the size
///   of its container window.
/// - **capturesSystemKeys**: When enabled, system-level key commands are intercepted by the guest VM.
/// - **disablesInputRedirection**: When enabled, mouse and keyboard events are ignored, making the display
///   effectively non-interactive (preview-only).
public struct AppleFramebufferView: NSViewRepresentable, FramebufferView {
        
    /// Indicates whether the VM display should automatically resize to match its container.
    public let automaticallyReconfiguresDisplay: Bool
    
    /// Indicates whether system key commands should be captured by the VM.
    public let capturesSystemKeys: Bool
    
    /// Determines if mouse and keyboard events should be forwarded to the VM.
    ///
    /// When `true`, input events are suppressed, allowing the display to act as a read-only preview.
    public let disablesInputRedirection: Bool
    
    /// The underlying virtual machine instance whose display is rendered by this view.
    ///
    /// This property provides the necessary connection to the VM’s display and state.
    private let vzVirtualMachine: VZVirtualMachine
    
    /// Creates and configures the NSView that displays the virtual machine screen.
    ///
    /// This method instantiates the internal `NSView` subclass,
    /// sets its virtual machine and input behavior, and returns it for embedding in the SwiftUI hierarchy.
    ///
    /// - Parameter context: The context provided by SwiftUI for managing the view’s lifecycle.
    /// - Returns: A fully configured NSView that displays the virtual machine’s output.
    public func makeNSView(context: Context) -> NSView {
        let vmView: VZVirtualMachineView = .init()
        vmView.virtualMachine = vzVirtualMachine
        vmView.disablesInputRedirection = disablesInputRedirection
        return vmView
    }
    
    /// Updates the existing NSView with new configuration values.
    ///
    /// This method is automatically invoked by SwiftUI when the view’s state changes, ensuring that
    /// properties such as `automaticallyReconfiguresDisplay` and `capturesSystemKeys` are kept in sync
    /// with the underlying VM view.
    ///
    /// - Parameters:
    ///   - nsView: The existing NSView instance to update.
    ///   - context: The context provided by SwiftUI for coordinating updates.
    public func updateNSView(_ nsView: NSView, context: Context) {
        
        guard let vmView = nsView as? VZVirtualMachineView else {
            VZKitLogger.default.fatalError("AppleFramebufferView unexpectedly received \(type(of: nsView))")
        }
        
        vmView.virtualMachine = vzVirtualMachine
        vmView.automaticallyReconfiguresDisplay = automaticallyReconfiguresDisplay
        vmView.capturesSystemKeys = capturesSystemKeys
        vmView.disablesInputRedirection = disablesInputRedirection
    }
    
    /// Initializes an `AppleFramebufferView` with a specified virtual machine instance and configuration.
    ///
    /// - Parameters:
    ///   - virtualMachine: The virtual machine instance (of type `AppleVirtualMachine<Template>`) whose display will be rendered.
    ///   - automaticallyReconfiguresDisplay: If `true`, the VM display will adjust its layout based on the container's size. Defaults to `false`.
    ///   - capturesSystemKeys: If `true`, the VM will intercept system-wide key commands. Defaults to `false`.
    ///   - disablesInputRedirection: If `true`, the view will ignore mouse and keyboard inputs, making it non-interactive. Defaults to `true`.
    public init<Template: TransferableTemplate>(
        virtualMachine: AppleVirtualMachine<Template>,
        automaticallyReconfiguresDisplay: Bool = false,
        capturesSystemKeys: Bool = false,
        disablesInputRedirection: Bool = true
    ) {
        self.vzVirtualMachine = virtualMachine.vzVirtualMachine
        self.automaticallyReconfiguresDisplay = automaticallyReconfiguresDisplay
        self.capturesSystemKeys = capturesSystemKeys
        self.disablesInputRedirection = disablesInputRedirection
    }
}
