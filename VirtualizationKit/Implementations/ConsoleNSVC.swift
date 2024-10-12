//
//  ConsoleViewController.swift
//  VirtHandler
//
//  Created by Giuseppe Rocco on 25/04/24.
//

import Virtualization
    
/// The Virtual machine console AppKit view controller
///
/// @brief
///    This is just a simple `AppKit` view controller that should
///    manage our `VZVirtualMachineView` object. Since the application
///    uses SwiftUI this will be wrapped up by a `NSViewControllerRepresentable`.
public class ConsoleNSVC: NSViewController, VZKitConsoleNSVC {
    
    public let vmView = VZVirtualMachineView()
    
    override public func loadView() {
        view = NSView()
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(vmView)
        
        NSLayoutConstraint.activate([
            vmView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            vmView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            vmView.topAnchor.constraint(equalTo: view.topAnchor),
            vmView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
}
