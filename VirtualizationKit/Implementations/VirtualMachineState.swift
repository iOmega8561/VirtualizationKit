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
//  VirtualMachineState.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 15/05/24.
//

import SwiftUI
import Virtualization

/// This typealias allows for cleaner-looking code
public typealias VirtualMachineState = VZVirtualMachine.State

/// Conformation to `VirtHandlerMachineState` helps us define two crucial methods that will significally reduce
/// the bulk of `SwiftUI` statements. We can simply get the assigned color and label of the given
/// `VirtualMachineState` by callin these methods.
extension VirtualMachineState: VZKitMachineState {
    
    public var color: Color {
        switch self {
        case .running:
            return .green
            
        case .stopping:
            return .orange
            
        case .stopped:
            return .red
            
        case .error:
            return .yellow
        
        case .starting:
            return .blue
            
        case .pausing:
            return .orange
            
        case .paused:
            return .orange
        
        case .resuming:
            return .orange
        
        case .restoring:
            return .mint
            
        default:
            return .white
        }
    }
    
    public var localized: String {
        switch self {
        case .running:
            return String(
                localized: "details-vmstate-running",
                bundle: VirtualizationKit.bundle
            )
            
        case .stopping:
            return String(
                localized: "details-vmstate-stopping",
                bundle: VirtualizationKit.bundle
            )
            
        case .stopped:
            return String(
                localized: "details-vmstate-stopped",
                bundle: VirtualizationKit.bundle
            )
        
        case .error:
            return String(
                localized: "details-vmstate-error",
                bundle: VirtualizationKit.bundle
            )
        
        case .starting:
            return String(
                localized: "details-vmstate-starting",
                bundle: VirtualizationKit.bundle
            )
        
        case .paused:
            return String(
                localized: "details-vmstate-paused",
                bundle: VirtualizationKit.bundle
            )
        
        case .pausing:
            return String(
                localized: "details-vmstate-pausing",
                bundle: VirtualizationKit.bundle
            )
            
        case .resuming:
            return String(
                localized: "details-vmstate-resuming",
                bundle: VirtualizationKit.bundle
            )
        
        case .restoring:
            return String(
                localized: "details-vmstate-restoring",
                bundle: VirtualizationKit.bundle
            )
               
        default:
            return String("default-state")
        }
    }
}
