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

import Foundation

import os

/// A scope guard around a security-scoped resource.
///
/// Inside the App Sandbox, a file the user picked outside of the application container is only
/// reachable while access to its security-scoped URL is active. The access is started when the guard
/// is created and stopped when the last reference to it goes away, which ties the lifetime of the
/// sandbox extension to the lifetime of whatever owns the guard (a virtual machine, an attached device).
///
/// Starting access on a URL that carries no security scope is harmless: the call reports `false` and
/// nothing is balanced on release. This makes the guard safe to use unconditionally, for sandboxed and
/// non-sandboxed hosts alike.
///
/// - Important: A URL loses its security scope when it is encoded and decoded. The embedding
///   application is expected to persist a security-scoped bookmark and to hand the framework a URL
///   freshly resolved from it.
final class SecurityScopedAccess: Sendable {

    /// The resource this guard keeps reachable.
    private let url: URL

    /// Whether access was actually started, and therefore has to be balanced.
    private let isAccessing: Bool

    /// Starts accessing the resource.
    ///
    /// - Parameter url: The location of the resource.
    init(url: URL) {
        self.url = url
        self.isAccessing = url.startAccessingSecurityScopedResource()
    }

    deinit {
        if isAccessing { url.stopAccessingSecurityScopedResource() }
    }
}

/// A thread-safe set of scope guards, keyed by the identifier of the device that uses the resource.
///
/// Devices attached while a machine runs (removable media) need their backing file for as long as they
/// stay attached, which is unrelated to any lexical scope.
final class SecurityScopeRegistry: Sendable {

    /// The guards currently held, by device identifier.
    private let guards = OSAllocatedUnfairLock<[UUID: SecurityScopedAccess]>(initialState: [:])

    /// Keeps a resource reachable until `release(_:)` is called for the same identifier.
    ///
    /// - Parameters:
    ///   - access: The guard to hold on to.
    ///   - id: The identifier of the device backed by the resource.
    func retain(_ access: SecurityScopedAccess, for id: UUID) {
        guards.withLock { $0[id] = access }
    }

    /// Drops the guard registered for a device, ending access to its resource.
    ///
    /// - Parameter id: The identifier of the device.
    func release(_ id: UUID) {
        guards.withLock { $0[id] = nil }
    }
}
