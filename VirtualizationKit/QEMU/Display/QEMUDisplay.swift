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

import CoreGraphics

import Foundation

import os

/// The guest display of one QEMU virtual machine, shared by every view that shows it.
///
/// The display owns the connection to the emulator's display server while the machine is on. It keeps
/// the most recent frame and pointer image, pushes them to the attached views, and forwards their
/// input to the guest.
///
/// ## Delivery
/// Frames are produced on the connection's reading thread, possibly faster than the main thread can
/// draw them. They pass through a single-slot mailbox: a newer frame replaces one that has not been
/// picked up yet, so a stalled main thread holds at most one pending frame, however long the stall.
/// Pick-ups are scheduled on the main dispatch queue, which runs them in the order they were
/// scheduled, and each one runs isolated to the main actor.
@MainActor
final class QEMUDisplay {

    /// What the reading thread has delivered and the main actor has not picked up yet.
    private struct Mailbox: Sendable {

        /// The connection the content belongs to. Content of an earlier connection is dropped.
        var generation: UInt64 = 0

        /// The newest frame.
        var frame: RFBFrame?

        /// The newest pointer image.
        var cursor: RFBCursor?

        /// Whether the connection has ended.
        var isClosed = false

        /// The reason the connection ended, if it failed.
        var failure: (any Error)?

        /// Whether a pick-up is already scheduled on the main queue.
        var isScheduled = false
    }

    /// The handover point between the reading thread and the main actor.
    nonisolated private let mailbox = OSAllocatedUnfairLock(initialState: Mailbox())

    /// The most recent image of the guest display, or `nil` while there is none.
    private(set) var frame: CGImage?

    /// The most recent pointer image of the guest, or `nil` until the guest has defined one.
    private(set) var cursor: RFBCursor?

    /// The last failure of the display, if any. Cleared when a new connection is attached.
    ///
    /// A display failure never stops the machine; it is only recorded and logged.
    private(set) var failure: (any Error)?

    /// The connection to the display server, while there is one.
    private var connection: RFBConnection?

    /// Identifies the current connection. Incremented on every attach and detach.
    private var generation: UInt64 = 0

    /// The views showing this display. Held weakly: a view that goes away simply stops being updated.
    private let views = NSHashTable<QEMUFramebufferNSView>.weakObjects()

    /// Whether the guest draws its pointer into the framebuffer itself until it defines a pointer image.
    ///
    /// A guest without a driver for the virtio GPU (Windows) never sends a pointer image; its pointer
    /// is part of every frame. Views then hide the host pointer over the display instead of showing a
    /// second one on top. Once the guest does define a pointer image, that image is shown as usual.
    let guestDrawsPointer: Bool

    /// Creates a display.
    ///
    /// - Parameter guestDrawsPointer: Whether the guest draws its own pointer into the framebuffer.
    init(guestDrawsPointer: Bool = false) {
        self.guestDrawsPointer = guestDrawsPointer
    }

    /// The size of the guest display, in pixels, or zero while there is no frame.
    var frameSize: CGSize {
        guard let frame else { return .zero }
        return CGSize(width: frame.width, height: frame.height)
    }

    // MARK: - Connection

    /// Starts showing the guest through a connection to its display server.
    ///
    /// A connection that is still attached is closed first.
    ///
    /// - Parameter socket: The client end of a connection the display server has accepted.
    /// - Returns: A token that identifies this connection to `detach(generation:)`.
    @discardableResult
    func attach(_ socket: UnixSocket) -> UInt64 {

        detach()

        let generation = self.generation
        let connection = RFBConnection(socket: socket, handler: Self.makeHandler(for: self, generation: generation))

        self.failure = nil
        self.connection = connection

        connection.start()
        return generation
    }

    /// Closes the connection, if it is the one a token was issued for.
    ///
    /// - Parameter generation: The token returned by `attach(_:)`.
    func detach(generation: UInt64) {
        guard generation == self.generation else { return }
        detach()
    }

    /// Closes the connection, if any, and clears the display.
    func detach() {

        connection?.close()
        connection = nil

        generation &+= 1

        let generation = self.generation
        mailbox.withLock { $0 = Mailbox(generation: generation) }

        frame = nil
        cursor = nil

        for view in views.allObjects {
            view.displayDidChangeCursor()
            view.displayDidUpdateFrame()
        }
    }

    /// Records a failure of the display and logs it.
    ///
    /// - Parameter error: The failure, typically a `VZKitError.qemuDisplayFailure`.
    func report(_ error: any Error) {
        failure = error
        VZKitLogger.default.error(error.localizedDescription)
    }

    // MARK: - Views

    /// Starts pushing frames and pointer images to a view.
    ///
    /// - Parameter view: The view. It is held weakly.
    func register(_ view: QEMUFramebufferNSView) {
        views.add(view)
    }

    /// Stops pushing frames and pointer images to a view.
    ///
    /// - Parameter view: The view.
    func unregister(_ view: QEMUFramebufferNSView) {
        views.remove(view)
    }

    // MARK: - Input

    /// Forwards the pointer position and button state. See `RFBConnection.sendPointer(buttons:x:y:)`.
    func sendPointer(buttons: UInt8, x: Int, y: Int) {
        connection?.sendPointer(buttons: buttons, x: x, y: y)
    }

    /// Forwards a key press or release. See `RFBConnection.sendKey(scancode:keysym:isDown:)`.
    func sendKey(scancode: UInt16, keysym: UInt32, isDown: Bool) {
        connection?.sendKey(scancode: scancode, keysym: keysym, isDown: isDown)
    }

    /// Asks the guest for a new display resolution.
    ///
    /// - Returns: Whether the request was sent; `false` while no connection is established.
    func requestDisplaySize(width: Int, height: Int) -> Bool {
        connection?.sendDesktopSize(width: width, height: height) ?? false
    }

    // MARK: - Delivery

    /// Builds the event handler of a connection. It runs on the reading thread and only touches the
    /// mailbox, which is why it is created outside of the main actor.
    nonisolated private static func makeHandler(
        for display: QEMUDisplay,
        generation: UInt64
    ) -> @Sendable (RFBConnection.Event) -> Void {
        { [weak display] event in
            display?.post(event, generation: generation)
        }
    }

    /// Leaves an event in the mailbox and schedules a pick-up unless one is pending already.
    nonisolated private func post(_ event: RFBConnection.Event, generation: UInt64) {

        let needsPickUp = mailbox.withLock { box -> Bool in

            guard box.generation == generation else { return false }

            switch event {
            case .frame(let frame): box.frame = frame
            case .cursor(let cursor): box.cursor = cursor
            case .closed(let failure):
                box.isClosed = true
                box.failure = failure
            }

            guard !box.isScheduled else { return false }

            box.isScheduled = true
            return true
        }

        guard needsPickUp else { return }

        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                self?.pickUp()
            }
        }
    }

    /// Takes everything out of the mailbox and applies it.
    private func pickUp() {

        let box = mailbox.withLock { box -> Mailbox in
            let delivered = box
            box = Mailbox(generation: box.generation)
            return delivered
        }

        guard box.generation == generation else { return }

        if let cursor = box.cursor {
            self.cursor = cursor
            for view in views.allObjects { view.displayDidChangeCursor() }
        }

        if let frame = box.frame {
            self.frame = frame.image
            for view in views.allObjects { view.displayDidUpdateFrame() }
        }

        if box.isClosed {
            connection = nil

            if let failure = box.failure {
                report(VZKitError.qemuDisplayFailure(String(describing: failure)))
            }
        }
    }
}
