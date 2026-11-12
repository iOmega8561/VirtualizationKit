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

/// A virtual machine backed by QEMU.
///
/// `QEMUVirtualMachine` is the counterpart of the Apple-backed machine and is used the same way: it is
/// created from a template, exposes a state coordinator, and is driven through `execute(action:)`.
///
/// ```swift
/// let vm = try await QEMUVirtualMachine(template: template)
/// try await vm.execute(action: .start())
/// ```
///
/// What differs is where the guest runs. The emulator is not part of the application process: it is
/// hosted by a sandboxed helper service that ships with the framework, and this type merely holds the
/// connection to it. Creating a machine validates the template and provisions its files, but starts
/// nothing; the emulator process exists from `.start` until the guest powers off or `.stop` is executed.
///
/// ## Concurrency
/// Like its Apple counterpart this is a lightweight, `Sendable` value that can be copied freely. All
/// copies refer to the same engine, which serializes the actions executed on the machine.
public struct QEMUVirtualMachine<Template: TransferableTemplate>: VirtualMachine {

    /// The high-level actions that can be performed on a QEMU virtual machine.
    ///
    /// - `.start(options:)`: Power the machine on.
    /// - `.stop`: Power the machine off without involving the guest.
    /// - `.pause`: Halt the guest processors.
    /// - `.resume`: Let a paused guest run again.
    public enum Action: ExecutableAction {
        case start(options: QEMUStartOptions?)
        case stop
        case pause
        case resume
    }

    /// The configuration template describing the machine.
    public let template: Template

    /// The backend-specific settings the machine was created with.
    public let options: QEMUMachineOptions

    /// Tracks the execution state of the machine and broadcasts its changes on the main actor.
    public let stateCoordinator: QEMUStateCoordinator

    /// Drives the emulator process. Shared by all copies of this value.
    let engine: QEMUEngine

    /// The guest display, shown by `QEMUFramebufferView`. Shared by all copies of this value.
    let display: QEMUDisplay

    /// Executes a high-level action.
    ///
    /// - Parameter action: The requested operation.
    /// - Throws: A localized error if the action is not possible in the current state, if the helper
    ///   service is unavailable, or if the emulator fails. When the emulator exits during start-up,
    ///   the error carries the diagnostics it printed.
    public func execute(action: Action) async throws {
        switch action {
        case .start(let options):
            try await engine.start(paused: options?.startsPaused ?? false)
        case .stop:
            try await engine.stop()
        case .pause:
            try await engine.pause()
        case .resume:
            try await engine.resume()
        }
    }

    /// Creates a machine with the default backend options.
    ///
    /// - Parameter template: The template describing the machine.
    /// - Throws: A localized error if the template asks for something this backend does not support,
    ///   if the helper service is not embedded, or if the files of the machine cannot be provisioned.
    public init(template: Template) async throws {
        try await self.init(template: template, options: .init())
    }

    /// Creates a machine with explicit backend options.
    ///
    /// - Parameters:
    ///   - template: The template describing the machine.
    ///   - options: The backend-specific settings, such as the guest architecture.
    /// - Throws: A localized error if the template asks for something this backend does not support,
    ///   if the helper service is not embedded, or if the files of the machine cannot be provisioned.
    public init(template: Template, options: QEMUMachineOptions) async throws {

        let builder = try await QEMUConfigurationBuilder(template: template, options: options)
        let plan = try builder.createLaunchPlan()
        let stateCoordinator = await QEMUStateCoordinator()
        let display = await QEMUDisplay()

        self.template = template
        self.options = options
        self.stateCoordinator = stateCoordinator
        self.display = display
        self.engine = .init(plan: plan, helper: builder.helper, coordinator: stateCoordinator)
    }
}

public extension QEMUVirtualMachine {

    /// Presses the virtual power button.
    ///
    /// The guest decides how to react; an operating system with power management shuts itself down,
    /// after which the machine reports `.stopped`. Use `.stop` to power off unconditionally.
    func requestPowerDown() async throws {
        try await engine.requestPowerDown()
    }

    /// Resets the machine without powering it off, as the reset button of a physical one would.
    func reset() async throws {
        try await engine.reset()
    }

    /// The last failure of the guest display, if any.
    ///
    /// A display failure does not stop the machine: the guest keeps running, only the framebuffer
    /// views stay empty. The value is cleared when the machine is powered on again.
    @MainActor
    var displayFailure: (any Error)? {
        display.failure
    }
}
