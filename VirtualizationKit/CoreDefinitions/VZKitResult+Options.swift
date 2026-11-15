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

public extension VZKitResult {

    /// Creates a result from any expression that creates a virtual machine.
    ///
    /// This is the general form of the type-based initializer, for virtual machines whose creation
    /// involves more than a call to their initializer:
    ///
    /// ```swift
    /// let result = await VZKitResult {
    ///     let options = AppleMachineOptions(platform: try await .macOS(restoreImageAt: imageURL))
    ///     return try await AppleVirtualMachine(template: template, options: options)
    /// }
    /// ```
    ///
    /// - Parameter makeVirtualMachine: Creates the virtual machine. Whatever it throws is captured in
    ///   the `.failure` case.
    /// - Important: This initializer does not throw; errors are captured within the result.
    init(_ makeVirtualMachine: @Sendable () async throws -> any VirtualMachine) async {
        do {
            self = .success(try await makeVirtualMachine())
        } catch {
            self = .failure(error)
        }
    }
}
