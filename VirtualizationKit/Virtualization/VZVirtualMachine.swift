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
