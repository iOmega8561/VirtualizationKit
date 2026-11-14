//
//  Copyright 2026 Giuseppe Rocco
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
//  VZGenericMachineIdentifier.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 14/11/2026.
//

import Virtualization.VZGenericMachineIdentifier

/// Extends `VZGenericMachineIdentifier` to conform to the `MachineIdentifier` protocol.
///
/// This extension enables `VZGenericMachineIdentifier` to leverage the default functionality provided
/// by the `MachineIdentifier` protocol, including serialization, deserialization, and file-based persistence.
extension VZGenericMachineIdentifier: MachineIdentifier {}
