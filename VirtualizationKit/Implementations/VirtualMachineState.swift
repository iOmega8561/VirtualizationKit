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
               
        default:
            return .white
        }
    }
    
    public var localized: String {
        switch self {
        case .running:
            return String(
                localized: "details-vmstate-running",
                bundle: Bundle(identifier: "giusepperocco.VirtualizationKit")
            )
            
        case .stopping:
            return String(
                localized: "details-vmstate-stopping",
                bundle: Bundle(identifier: "giusepperocco.VirtualizationKit")
            )
            
        case .stopped:
            return String(
                localized: "details-vmstate-stopped",
                bundle: Bundle(identifier: "giusepperocco.VirtualizationKit")
            )
        
        case .error:
            return String(
                localized: "details-vmstate-error",
                bundle: Bundle(identifier: "giusepperocco.VirtualizationKit")
            )
        
        case .starting:
            return String(
                localized: "details-vmstate-starting",
                bundle: Bundle(identifier: "giusepperocco.VirtualizationKit")
            )
        
        case .paused:
            return String(
                localized: "details-vmstate-paused",
                bundle: Bundle(identifier: "giusepperocco.VirtualizationKit")
            )
        
        case .pausing:
            return String(
                localized: "details-vmstate-pausing",
                bundle: Bundle(identifier: "giusepperocco.VirtualizationKit")
            )
            
        case .resuming:
            return String(
                localized: "details-vmstate-resuming",
                bundle: Bundle(identifier: "giusepperocco.VirtualizationKit")
            )
               
        default:
            return String("default-state")
        }
    }
}
