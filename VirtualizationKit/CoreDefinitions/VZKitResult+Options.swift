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
    /// This is the general form of the type-based initializer, for virtual machines that take more
    /// than a template, such as options:
    ///
    /// ```swift
    /// let result = await VZKitResult {
    ///     try await QEMUVirtualMachine(template: template, options: options)
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

    /// Creates a QEMU virtual machine with machine options, capturing the outcome.
    ///
    /// The counterpart of `init(_:using:)` for the QEMU backend, which takes options in addition to the
    /// template. That initializer creates QEMU machines with default options.
    ///
    /// ```swift
    /// let result = await VZKitResult(
    ///     QEMUVirtualMachine<MyTemplate>.self,
    ///     using: template,
    ///     options: .init(architecture: .aarch64, includesTPM: true)
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - vmType: The QEMU virtual machine type, specialised for the template type.
    ///   - template: The template describing the machine.
    ///   - options: The options of the QEMU backend.
    /// - Important: This initializer does not throw; errors are captured within the result.
    init<Template: TransferableTemplate>(
        _ vmType: QEMUVirtualMachine<Template>.Type,
        using template: Template,
        options: QEMUMachineOptions
    ) async {
        self = await VZKitResult {
            try await vmType.init(template: template, options: options)
        }
    }
}
