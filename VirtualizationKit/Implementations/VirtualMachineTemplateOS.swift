//
//  VirtualMachineTemplateOS.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 12/10/24.
//

import SwiftUI

/// The codable structure that will store the information about our VM's operating system
///
/// @brief
///    It stores the operating system type and a boolean variable that tells us if the OS
///    needs an installation procedure. The init method sets the latter to true for MacOS.
///    Conformation to `VZKitTemplateOS` helps us define two crucial methods that will significally reduce
///    the bulk of `SwiftUI` statements. We can simply get the assets of the given OS by callin these methods.
public struct VirtualMachineTemplateOS: VZKitTemplateOS {
    
    /// The Operating System of choice
    public let type: VirtualMachineOS
    
    /// A boolean value that dictates if an installation procedure is needed
    public var needsInstall: Bool
    
    /// The `URL` of the given installer .ISO or .IPSW file (disk image),
    public var installer: URL?
    
    /// The initializer of the struct
    ///
    /// - Parameters:
    ///   - type: The Operating System of choice,
    ///   - installer: The `URL` of the given installer .ISO or .IPSW file (disk image).
    public init(type: VirtualMachineOS, installer: URL) {
        self.type = type
        self.installer = installer
        
        switch type {
        case .macos:
            self.needsInstall = true
        default:
            self.needsInstall = false
        }
    }
}
