//
//  VZKitConsoleNSVC.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 12/10/24.
//

import SwiftUI

import Virtualization

public protocol VZKitConsoleNSVC: NSViewController {
    
    var vmView: VZVirtualMachineView { get }
    
    @MainActor func loadView()
    
    @MainActor func viewDidLoad()
}
