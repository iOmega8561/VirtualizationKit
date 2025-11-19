//
//  Copyright 2025 Giuseppe Rocco
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
//  -----------------------------------------------------------------------
//
//  VZKeyboardConfiguration.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 18/05/24.
//

import Virtualization

extension VZKeyboardConfiguration: SpecializedConstructible {
    
    /// Much simpler than the other factory methods, this one just returns the appropriate keyboard
    /// configuration according to the OS of choice.
    ///
    /// - Parameters:
    ///   - type: The guest operating system.
    static func create(type: OperatingSystem) -> Product {
        
        switch type {
        case .macos(let version):
            
            guard version.major > 12  else { fallthrough }
            
            return VZMacKeyboardConfiguration()
            
        case .linux:
            
            return VZUSBKeyboardConfiguration()
        }
    }
}
