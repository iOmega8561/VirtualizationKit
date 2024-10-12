//
//  VZKitViewController 2.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 12/10/24.
//


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
//  VZKitConsoleNSVCR.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 12/10/24.
//

import SwiftUI

import Virtualization

public protocol VZKitConsoleNSVCR: NSViewControllerRepresentable {
    
    associatedtype CoordinatorType: NSObject
    
    associatedtype ControllerType: VZKitConsoleNSVC
    
    associatedtype TemplateType: VZKitTemplate
    
    @MainActor var result: VZKitResult<TemplateType>? { get }
    
    @MainActor var isScreenAdaptive: Binding<Bool> { get set }
    
    @MainActor var areKeysCaptured: Binding<Bool> { get set }
    
    @MainActor func makeCoordinator() -> CoordinatorType
    
    @MainActor func makeNSViewController(context: Context) -> ControllerType
    
    @MainActor func updateNSViewController(_ nsViewController: ControllerType, context: Context)
}
