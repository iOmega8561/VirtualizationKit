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

import AppKit

import SwiftUI

/// A SwiftUI view that shows the display of a QEMU virtual machine and forwards input to it.
///
/// This is the counterpart of the framebuffer view of the Apple backend and is configured the same
/// way:
/// - **automaticallyReconfiguresDisplay**: When enabled, the guest is asked to change its resolution
///   to the size of the view, in pixels, whenever the view settles on a new size.
/// - **capturesSystemKeys**: When enabled, key combinations that would otherwise trigger menu items of
///   the host application (such as Command-Q) are sent to the guest instead. Shortcuts that the system
///   handles before any application sees them, such as Command-Tab, cannot be captured.
/// - **disablesInputRedirection**: When enabled, mouse and keyboard events are ignored and the view
///   lets clicks through, making it a preview of the guest.
///
/// Any number of views may show the same machine at the same time.
public struct QEMUFramebufferView: NSViewRepresentable, FramebufferView {

    /// Indicates whether the guest display should follow the size of the view.
    public let automaticallyReconfiguresDisplay: Bool

    /// Indicates whether key combinations claimed by the host application go to the guest.
    public let capturesSystemKeys: Bool

    /// Determines if mouse and keyboard events are ignored.
    ///
    /// When `true`, input events are suppressed, allowing the display to act as a read-only preview.
    public let disablesInputRedirection: Bool

    /// The display of the machine shown by this view.
    private let display: QEMUDisplay

    /// Creates the AppKit view that shows the guest.
    ///
    /// - Parameter context: The context provided by SwiftUI.
    /// - Returns: The configured view.
    public func makeNSView(context: Context) -> NSView {
        let view = QEMUFramebufferNSView(display: display)
        configure(view)
        return view
    }

    /// Applies the current configuration to an existing view.
    ///
    /// - Parameters:
    ///   - nsView: The view created by `makeNSView(context:)`.
    ///   - context: The context provided by SwiftUI.
    public func updateNSView(_ nsView: NSView, context: Context) {

        guard let view = nsView as? QEMUFramebufferNSView else {
            VZKitLogger.default.fatalError("QEMUFramebufferView unexpectedly received \(type(of: nsView))")
        }

        configure(view)
    }

    /// Releases every key and button the view still holds before it goes away.
    ///
    /// - Parameters:
    ///   - nsView: The view being removed.
    ///   - coordinator: The coordinator of the view, unused.
    public static func dismantleNSView(_ nsView: NSView, coordinator: Void) {
        (nsView as? QEMUFramebufferNSView)?.releaseInput()
    }

    /// Copies the configuration of this value into a view.
    private func configure(_ view: QEMUFramebufferNSView) {
        view.guestDisplay = display
        view.automaticallyReconfiguresDisplay = automaticallyReconfiguresDisplay
        view.capturesSystemKeys = capturesSystemKeys
        view.disablesInputRedirection = disablesInputRedirection
    }

    /// Creates a view showing the display of a QEMU virtual machine.
    ///
    /// - Parameters:
    ///   - virtualMachine: The machine whose display is shown.
    ///   - automaticallyReconfiguresDisplay: If `true`, the guest resolution follows the size of the view. Defaults to `false`.
    ///   - capturesSystemKeys: If `true`, key combinations claimed by the host application go to the guest. Defaults to `false`.
    ///   - disablesInputRedirection: If `true`, the view ignores mouse and keyboard input. Defaults to `true`.
    public init<Template: TransferableTemplate>(
        virtualMachine: QEMUVirtualMachine<Template>,
        automaticallyReconfiguresDisplay: Bool = false,
        capturesSystemKeys: Bool = false,
        disablesInputRedirection: Bool = true
    ) {
        self.display = virtualMachine.display
        self.automaticallyReconfiguresDisplay = automaticallyReconfiguresDisplay
        self.capturesSystemKeys = capturesSystemKeys
        self.disablesInputRedirection = disablesInputRedirection
    }
}

/// The AppKit view behind `QEMUFramebufferView`.
///
/// The view is layer-backed. The current frame is the content of a sublayer that scales it to fit the
/// view while preserving its aspect ratio, so the guest display is letterboxed when the proportions
/// differ. Pointer positions are mapped back through the same transformation, and clamped to the
/// display, before they are sent.
final class QEMUFramebufferNSView: NSView, FramebufferNSView {

    // MARK: - Configuration

    /// Whether input is ignored. While it is, the view is transparent to clicks.
    var disablesInputRedirection = true {
        didSet {
            guard disablesInputRedirection != oldValue else { return }

            if disablesInputRedirection {
                releaseInput()

                if window?.firstResponder === self { window?.makeFirstResponder(nil) }
            }

            window?.invalidateCursorRects(for: self)
        }
    }

    /// Whether the guest is asked to follow the size of the view.
    var automaticallyReconfiguresDisplay = false {
        didSet {
            guard automaticallyReconfiguresDisplay != oldValue else { return }

            lastRequestedSize = nil
            scheduleResolutionUpdate()
        }
    }

    /// Whether key equivalents go to the guest rather than to the menus of the host application.
    var capturesSystemKeys = false

    /// The display shown by this view.
    var guestDisplay: QEMUDisplay {
        didSet {
            guard guestDisplay !== oldValue else { return }

            releaseInput(on: oldValue)
            oldValue.unregister(self)
            guestDisplay.register(self)

            lastRequestedSize = nil
            displayDidChangeCursor()
            displayDidUpdateFrame()
        }
    }

    // MARK: - State

    /// The layer showing the current frame.
    private let imageLayer = CALayer()

    /// The size of the frame currently shown, in guest pixels.
    private var shownFrameSize: CGSize = .zero

    /// The mouse buttons currently held, as an RFB button mask.
    private var buttonMask: UInt8 = 0

    /// The last pointer position sent, in guest pixels.
    private var lastPointerPosition: (x: Int, y: Int) = (0, 0)

    /// Scrolling not yet turned into wheel steps.
    private var scrollAccumulator: CGFloat = 0

    /// The keys currently held in the guest, by virtual key code, with what was sent for them.
    private var pressedKeys: [UInt16: (scancode: UInt16, keysym: UInt32)] = [:]

    /// The keys pressed while Command was held. AppKit does not report their release.
    private var commandChordKeys: Set<UInt16> = []

    /// The tracking area delivering pointer movements.
    private var trackingArea: NSTrackingArea?

    /// The host pointer shown over the guest display, rebuilt when the guest pointer or the scale changes.
    private var guestCursor: NSCursor?

    /// The pending, debounced, resolution change.
    private var resolutionTask: Task<Void, Never>?

    /// The last resolution requested from the guest, so that the same request is not repeated.
    private var lastRequestedSize: (width: Int, height: Int)?

    /// The window whose key status is observed.
    private weak var observedWindow: NSWindow?

    /// The modifier keys, by virtual key code, with the flag that is set while one of them is held.
    private static let modifierFlags: [UInt16: NSEvent.ModifierFlags] = [
        0x36: .command, 0x37: .command,
        0x38: .shift, 0x3C: .shift,
        0x3A: .option, 0x3D: .option,
        0x3B: .control, 0x3E: .control
    ]

    /// A pointer that shows nothing, used while the guest hides its own.
    private static let hiddenCursor = NSCursor(image: NSImage(size: NSSize(width: 1, height: 1)), hotSpot: .zero)

    /// How long the size of the view has to stay the same before the guest is asked to follow it.
    private static let resolutionDebounce: Duration = .milliseconds(400)

    // MARK: - Initializers

    /// Creates a view showing a display.
    ///
    /// - Parameter display: The display to show.
    init(display: QEMUDisplay) {

        self.guestDisplay = display

        super.init(frame: .zero)

        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        imageLayer.contentsGravity = .resizeAspect
        imageLayer.actions = ["contents": NSNull(), "bounds": NSNull(), "position": NSNull()]
        layer?.addSublayer(imageLayer)

        display.register(self)
        displayDidChangeCursor()
        displayDidUpdateFrame()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Display Updates

    /// Shows the current frame of the display.
    func displayDidUpdateFrame() {

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        imageLayer.contents = guestDisplay.frame
        CATransaction.commit()

        let size = guestDisplay.frameSize

        guard size != shownFrameSize else { return }

        shownFrameSize = size
        rebuildCursor()
        scheduleResolutionUpdate()
    }

    /// Shows the current pointer image of the guest.
    func displayDidChangeCursor() {
        rebuildCursor()
    }

    // MARK: - Layout

    override var isOpaque: Bool { true }

    override func layout() {
        super.layout()

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        imageLayer.frame = bounds
        CATransaction.commit()
    }

    override func setFrameSize(_ newSize: NSSize) {
        let hasChanged = newSize != frame.size

        super.setFrameSize(newSize)

        guard hasChanged else { return }

        lastRequestedSize = nil
        rebuildCursor()
        scheduleResolutionUpdate()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()

        lastRequestedSize = nil
        scheduleResolutionUpdate()
    }

    /// The part of the view covered by the guest display, in view coordinates.
    private var contentRect: CGRect {

        let size = guestDisplay.frameSize

        guard size.width > 0, size.height > 0, bounds.width > 0, bounds.height > 0 else { return .zero }

        let scale = min(bounds.width / size.width, bounds.height / size.height)
        let width = size.width * scale
        let height = size.height * scale

        return CGRect(x: bounds.midX - width / 2, y: bounds.midY - height / 2, width: width, height: height)
    }

    /// Maps the location of an event to a guest pixel, clamped to the display.
    ///
    /// The view's origin is its bottom-left corner, the guest's is its top-left corner.
    private func guestPosition(of event: NSEvent) -> (x: Int, y: Int)? {

        let size = guestDisplay.frameSize
        let rect = contentRect

        guard rect.width > 0, rect.height > 0 else { return nil }

        let point = convert(event.locationInWindow, from: nil)
        let scale = rect.width / size.width

        let x = ((point.x - rect.minX) / scale).rounded(.down)
        let y = ((rect.maxY - point.y) / scale).rounded(.down)

        return (
            x: Int(min(max(x, 0), size.width - 1)),
            y: Int(min(max(y, 0), size.height - 1))
        )
    }

    // MARK: - Resolution

    /// Asks the guest to follow the size of the view once the size has stopped changing.
    private func scheduleResolutionUpdate() {

        resolutionTask?.cancel()

        guard automaticallyReconfiguresDisplay, window != nil else {
            resolutionTask = nil
            return
        }

        resolutionTask = Task { [weak self] in
            try? await Task.sleep(for: Self.resolutionDebounce)

            guard !Task.isCancelled else { return }

            self?.updateResolution()
        }
    }

    /// Sends the size of the view, in pixels, to the guest if it differs from the guest's.
    private func updateResolution() {

        guard automaticallyReconfiguresDisplay, let window else { return }

        let scale = window.backingScaleFactor

        // Even dimensions within the range the guest display supports.
        let width = min(max(Int((bounds.width * scale).rounded(.down)), 640), 7680) & ~1
        let height = min(max(Int((bounds.height * scale).rounded(.down)), 480), 4320) & ~1

        let current = guestDisplay.frameSize

        guard Int(current.width) != width || Int(current.height) != height else { return }

        if let lastRequestedSize, lastRequestedSize.width == width, lastRequestedSize.height == height {
            return
        }

        if guestDisplay.requestDisplaySize(width: width, height: height) {
            lastRequestedSize = (width, height)
        }
    }

    // MARK: - Pointer

    /// Whether input is currently forwarded.
    private var acceptsInput: Bool { !disablesInputRedirection }

    override var acceptsFirstResponder: Bool { acceptsInput }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { acceptsInput }

    override func hitTest(_ point: NSPoint) -> NSView? {
        disablesInputRedirection ? nil : super.hitTest(point)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea { removeTrackingArea(trackingArea) }

        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )

        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseDown(with event: NSEvent) {
        if acceptsInput { window?.makeFirstResponder(self) }
        pressButton(1, with: event)
    }

    override func mouseUp(with event: NSEvent) { releaseButton(1, with: event) }

    override func rightMouseDown(with event: NSEvent) { pressButton(4, with: event) }

    override func rightMouseUp(with event: NSEvent) { releaseButton(4, with: event) }

    override func otherMouseDown(with event: NSEvent) {
        if event.buttonNumber == 2 { pressButton(2, with: event) }
    }

    override func otherMouseUp(with event: NSEvent) {
        if event.buttonNumber == 2 { releaseButton(2, with: event) }
    }

    override func mouseMoved(with event: NSEvent) { sendPointer(for: event) }

    override func mouseDragged(with event: NSEvent) { sendPointer(for: event) }

    override func rightMouseDragged(with event: NSEvent) { sendPointer(for: event) }

    override func otherMouseDragged(with event: NSEvent) { sendPointer(for: event) }

    override func mouseEntered(with event: NSEvent) { sendPointer(for: event) }

    override func scrollWheel(with event: NSEvent) {

        guard acceptsInput, let position = guestPosition(of: event) else { return }

        // A trackpad reports fine-grained deltas, a wheel reports lines.
        let threshold: CGFloat = event.hasPreciseScrollingDeltas ? 12 : 1

        if event.phase == .began { scrollAccumulator = 0 }

        scrollAccumulator += event.scrollingDeltaY

        var steps = 0

        while abs(scrollAccumulator) >= threshold && steps < 10 {
            let direction: UInt8 = scrollAccumulator > 0 ? 8 : 16

            // A wheel step is a press immediately followed by a release; held buttons stay held.
            guestDisplay.sendPointer(buttons: buttonMask | direction, x: position.x, y: position.y)
            guestDisplay.sendPointer(buttons: buttonMask, x: position.x, y: position.y)

            scrollAccumulator -= scrollAccumulator > 0 ? threshold : -threshold
            steps += 1
        }

        if steps == 10 { scrollAccumulator = 0 }

        lastPointerPosition = position
    }

    /// Adds a button to the held ones and reports it.
    private func pressButton(_ button: UInt8, with event: NSEvent) {
        guard acceptsInput else { return }

        buttonMask |= button
        sendPointer(for: event)
    }

    /// Removes a button from the held ones and reports it.
    private func releaseButton(_ button: UInt8, with event: NSEvent) {
        guard acceptsInput else { return }

        buttonMask &= ~button
        sendPointer(for: event)
    }

    /// Reports the position of an event together with the buttons held.
    private func sendPointer(for event: NSEvent) {
        guard acceptsInput, let position = guestPosition(of: event) else { return }

        lastPointerPosition = position
        guestDisplay.sendPointer(buttons: buttonMask, x: position.x, y: position.y)
    }

    // MARK: - Cursor

    override func resetCursorRects() {

        guard acceptsInput else { return super.resetCursorRects() }

        let rect = contentRect

        guard !rect.isEmpty, let guestCursor else { return }

        addCursorRect(rect, cursor: guestCursor)
    }

    /// Rebuilds the host pointer from the guest's pointer image, at the scale the display is shown at.
    private func rebuildCursor() {

        defer { window?.invalidateCursorRects(for: self) }

        guard let cursor = guestDisplay.cursor else {
            guestCursor = nil
            return
        }

        guard let image = cursor.image else {
            guestCursor = Self.hiddenCursor
            return
        }

        let size = guestDisplay.frameSize
        let rect = contentRect
        let scale = size.width > 0 && rect.width > 0 ? rect.width / size.width : 1

        let pointSize = NSSize(
            width: max(CGFloat(image.width) * scale, 1),
            height: max(CGFloat(image.height) * scale, 1)
        )

        guestCursor = NSCursor(
            image: NSImage(cgImage: image, size: pointSize),
            hotSpot: NSPoint(x: cursor.hotspot.x * scale, y: cursor.hotspot.y * scale)
        )
    }

    // MARK: - Keyboard

    override func keyDown(with event: NSEvent) {
        guard acceptsInput else { return }

        pressKey(event.keyCode, keysym: Self.letterKeysym(of: event))

        if event.modifierFlags.contains(.command) { commandChordKeys.insert(event.keyCode) }
    }

    override func keyUp(with event: NSEvent) {
        guard acceptsInput else { return }

        releaseKey(event.keyCode)
        commandChordKeys.remove(event.keyCode)
    }

    override func flagsChanged(with event: NSEvent) {
        guard acceptsInput else { return }

        let keyCode = event.keyCode

        // Caps lock is reported once per physical press, alternately as on and off: a full press each time.
        if keyCode == QEMUKeyMap.capsLockKeyCode {
            pressKey(keyCode, keysym: 0)
            releaseKey(keyCode)
            return
        }

        guard let flag = Self.modifierFlags[keyCode] else { return }

        if pressedKeys[keyCode] != nil {
            releaseKey(keyCode)
        } else if event.modifierFlags.contains(flag) {
            pressKey(keyCode, keysym: 0)
        }

        // Keys pressed together with Command never report their release.
        if !event.modifierFlags.contains(.command) {
            for chordKey in commandChordKeys { releaseKey(chordKey) }
            commandChordKeys.removeAll()
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {

        guard capturesSystemKeys, acceptsInput, event.type == .keyDown,
              window?.firstResponder === self else {
            return super.performKeyEquivalent(with: event)
        }

        // The release of a key equivalent is not reported either; send a complete press.
        pressKey(event.keyCode, keysym: Self.letterKeysym(of: event))
        releaseKey(event.keyCode)
        return true
    }

    override func resignFirstResponder() -> Bool {
        releaseInput()
        return super.resignFirstResponder()
    }

    /// Sends a key press and remembers it, so that it can be released later.
    private func pressKey(_ keyCode: UInt16, keysym: UInt32) {

        guard let scancode = QEMUKeyMap.scancode(for: keyCode, isISOKeyboard: QEMUKeyMap.isISOKeyboard) else {
            return
        }

        pressedKeys[keyCode] = (scancode, keysym)
        guestDisplay.sendKey(scancode: scancode, keysym: keysym, isDown: true)
    }

    /// Sends the release of a key that was pressed through `pressKey(_:keysym:)`.
    private func releaseKey(_ keyCode: UInt16) {

        guard let key = pressedKeys.removeValue(forKey: keyCode) else { return }

        guestDisplay.sendKey(scancode: key.scancode, keysym: key.keysym, isDown: false)
    }

    /// The symbol of the letter an event produced, or `0` if it produced something else.
    ///
    /// The display server compares it with the state of the guest's caps lock to keep the two in step.
    private static func letterKeysym(of event: NSEvent) -> UInt32 {

        guard let characters = event.characters,
              characters.unicodeScalars.count == 1,
              let scalar = characters.unicodeScalars.first else { return 0 }

        switch scalar.value {
        case 0x41...0x5A, 0x61...0x7A: return scalar.value
        default: return 0
        }
    }

    // MARK: - Focus

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)

        releaseInput()

        if let observedWindow {
            NotificationCenter.default.removeObserver(
                self,
                name: NSWindow.didResignKeyNotification,
                object: observedWindow
            )
        }

        observedWindow = nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        if let window {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidResignKey(_:)),
                name: NSWindow.didResignKeyNotification,
                object: window
            )
        }

        observedWindow = window
        lastRequestedSize = nil
        scheduleResolutionUpdate()
    }

    /// Releases everything when the window stops receiving keyboard events.
    @objc private func windowDidResignKey(_ notification: Notification) {
        releaseInput()
    }

    /// Releases every key and mouse button still held in the guest.
    ///
    /// Without this, a modifier held while focus moves elsewhere would stay pressed in the guest.
    func releaseInput() {
        releaseInput(on: guestDisplay)
    }

    /// Releases every key and mouse button still held, on a given display.
    private func releaseInput(on display: QEMUDisplay) {

        for key in pressedKeys.values {
            display.sendKey(scancode: key.scancode, keysym: key.keysym, isDown: false)
        }

        pressedKeys.removeAll()
        commandChordKeys.removeAll()
        scrollAccumulator = 0

        if buttonMask != 0 {
            buttonMask = 0
            display.sendPointer(buttons: 0, x: lastPointerPosition.x, y: lastPointerPosition.y)
        }
    }
}
