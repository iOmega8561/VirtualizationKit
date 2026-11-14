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
//  VZVirtualMachine.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 12/05/2026.
//

import Virtualization

/// Extending to `@unchecked @retroactive Sendable` to
/// suppress concurrency-related warnings.
///
/// The Swift 6 compiler is much stricter on concurrency, so much so that importing dependencies
/// as `@preconcurrency` does not silence all warning, anymore.
/// The way this framework operates on `VZVirtualMachine` is completely safe.
extension VZVirtualMachine: @unchecked @retroactive Sendable {}
