//  CompositionToolbarContainer.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import GameController
import UIKit

/// Container that stacks the modern BBcode toolbar above the existing BBcode bar
final class CompositionToolbarContainer: UIInputView {

    // MARK: - Properties

    fileprivate(set) weak var textView: UITextView?

    /// Callback for when a toolbar action is triggered
    var onToolbarAction: ((ModernToolbarAction) -> Void)?

    var keyboardAppearance: UIKeyboardAppearance = .default {
        didSet {
            existingToolbar.keyboardAppearance = keyboardAppearance
            updateModernToolbarAppearance()
        }
    }

    var fontName: String? {
        didSet {
            modernToolbar.fontName = fontName
        }
    }

    /// Outline for the modern toolbar's blur buttons; see `ModernBBcodeToolbar.strokeColor`.
    var strokeColor: UIColor? {
        didSet {
            modernToolbar.strokeColor = strokeColor
        }
    }

    /// Adds a Poll button to the modern toolbar. Only the new thread composer sets this.
    var showsPollButton: Bool {
        get { modernToolbar.showsPollButton }
        set { modernToolbar.showsPollButton = newValue }
    }

    /// Marks the Poll button to show a poll is already attached.
    var pollIsAttached: Bool {
        get { modernToolbar.pollIsAttached }
        set { modernToolbar.pollIsAttached = newValue }
    }

    /// Adds a Specs button to the modern toolbar. Only the feedback-thread reply composer sets this.
    var showsSpecsButton: Bool {
        get { modernToolbar.showsSpecsButton }
        set { modernToolbar.showsSpecsButton = newValue }
    }

    private let modernToolbar: ModernBBcodeToolbar
    private let existingToolbar: CompositionInputAccessoryView
    private var observers: [NSObjectProtocol] = []

    // MARK: - Initialization

    init(textView: UITextView) {
        self.textView = textView
        self.modernToolbar = ModernBBcodeToolbar()
        self.existingToolbar = CompositionInputAccessoryView(textView: textView)

        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        let modernHeight: CGFloat = isIPad ? 52 : 44
        let existingHeight: CGFloat = isIPad ? 66 : 38
        let totalHeight = modernHeight + existingHeight

        let frame = CGRect(x: 0, y: 0, width: 0, height: totalHeight)
        super.init(frame: frame, inputViewStyle: .keyboard)

        setupViews(modernHeight: modernHeight)

        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: .main
        ) { [weak self] note in
            self?.keyboardWillChangeFrame(note)
        })
        observers.append(center.addObserver(
            forName: UIResponder.keyboardDidChangeFrameNotification, object: nil, queue: .main
        ) { [weak self] note in
            self?.keyboardDidChangeFrame(note)
        })
        for name in [Notification.Name.GCKeyboardDidConnect, .GCKeyboardDidDisconnect] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.isHardwareKeyboardConnected = Self.hardwareKeyboardIsConnected
            })
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    // MARK: - Setup

    private func setupViews(modernHeight: CGFloat) {
        // Modern toolbar setup
        modernToolbar.translatesAutoresizingMaskIntoConstraints = false
        modernToolbar.onAction = { [weak self] action in
            self?.onToolbarAction?(action)
        }
        modernToolbar.onToggleKeyboard = { [weak self] in
            guard let self, let textView = self.textView, self.canToggleKeyboard else { return }
            if textView.isKeyboardMinimized {
                textView.setKeyboardMinimized(false)
            } else if self.isKeyboardMinimizedBySystem {
                // The iPad keyboard's dismiss key collapses the keyboard without resigning the
                // text view, so a tap in the text does nothing; a fresh first-responder cycle is
                // what brings the keyboard back. With a real hardware keyboard it comes back
                // collapsed and the frame notification keeps the glyph on "restore".
                self.cycleFirstResponder()
            } else {
                textView.setKeyboardMinimized(true)
            }
            self.syncKeyboardToggle()
        }
        addSubview(modernToolbar)

        // Existing toolbar setup
        existingToolbar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(existingToolbar)

        NSLayoutConstraint.activate([
            // Modern toolbar at top
            modernToolbar.topAnchor.constraint(equalTo: topAnchor),
            modernToolbar.leadingAnchor.constraint(equalTo: leadingAnchor),
            modernToolbar.trailingAnchor.constraint(equalTo: trailingAnchor),
            modernToolbar.heightAnchor.constraint(equalToConstant: modernHeight),

            // Existing toolbar below
            existingToolbar.topAnchor.constraint(equalTo: modernToolbar.bottomAnchor),
            existingToolbar.leadingAnchor.constraint(equalTo: leadingAnchor),
            existingToolbar.trailingAnchor.constraint(equalTo: trailingAnchor),
            existingToolbar.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func updateModernToolbarAppearance() {
        modernToolbar.keyboardAppearance = keyboardAppearance
    }

    // MARK: - Keyboard toggle

    /// Whether iOS has collapsed the keyboard on its own because a hardware keyboard is connected.
    private var isKeyboardMinimizedBySystem = false {
        didSet {
            if isKeyboardMinimizedBySystem != oldValue { syncKeyboardToggle() }
        }
    }

    /// With a hardware keyboard connected, the software keyboard is the keyboard's business: its
    /// Eject key raises and lowers it, and iOS lowers it again whenever input views reload, so
    /// the toggle sits out rather than promise a restore it can't deliver.
    private var isHardwareKeyboardConnected = hardwareKeyboardIsConnected {
        didSet {
            if isHardwareKeyboardConnected != oldValue { syncKeyboardToggle() }
        }
    }

    private static var hardwareKeyboardIsConnected: Bool {
        #if targetEnvironment(simulator)
        // The simulator's keyboard capture shows up as a GCKeyboard while iOS still runs the
        // software keyboard normally, which would leave the toggle dimmed for no reason. The
        // keyboard-frame check above still catches the simulated hardware keyboard.
        return false
        #else
        return GCKeyboard.coalesced != nil
        #endif
    }

    /// iOS collapses the software keyboard to just this accessory view on its own when a
    /// hardware keyboard is connected, and when the iPad keyboard's dismiss key is pressed. Spot
    /// that from the keyboard frame so the toggle shows the restore glyph and, when tapped, tries
    /// a first-responder cycle rather than installing a second, redundant minimize.
    ///
    /// iOS describes that state two ways: a keyboard no taller than this accessory view, or (on
    /// first presentation) a zero-height frame parked at the bottom of the screen. Either way this
    /// accessory view is on screen, which is what tells it apart from a keyboard that's gone.
    private func keyboardDidChangeFrame(_ note: Notification) {
        guard let textView, let endFrame = keyboardEndFrame(from: note) else { return }

        isKeyboardMinimizedBySystem = isCollapsedKeyboardFrame(endFrame) && !textView.isKeyboardMinimized

        noteKeyboardEndFrame(endFrame)
        isKeyboardAnimating = false
        // A heal's own first-responder cycle ends with this notification.
        finishHealing()
        // This arrives once the keyboard has finished moving, so the host's layout is current on
        // the next tick; the layout-pass check below is the slower safety net.
        scheduleHealCheck(after: 0)
    }

    /// Records where the keyboard is heading before it starts moving. Layout passes during the
    /// animation would otherwise compare this view's final frame against the previous
    /// keyboard frame and, on a restore from minimized, mistake the rising keyboard for a
    /// stranded accessory.
    private func keyboardWillChangeFrame(_ note: Notification) {
        guard let endFrame = keyboardEndFrame(from: note) else { return }
        noteKeyboardEndFrame(endFrame)
        isKeyboardAnimating = true
        pendingHealCheck?.cancel()
    }

    private func keyboardEndFrame(from note: Notification) -> CGRect? {
        guard
            window != nil,
            let endFrame = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
            else { return nil }
        if let isLocal = note.userInfo?[UIResponder.keyboardIsLocalUserInfoKey] as? Bool, !isLocal { return nil }
        return endFrame
    }

    /// How tall the keyboard frame reports when it's collapsed to just this accessory view: this
    /// view plus the safe-area padding the keyboard host adds beneath it on home-indicator devices.
    private var accessoryOnlyHeight: CGFloat {
        bounds.height + (textView?.window?.safeAreaInsets.bottom ?? 0)
    }

    private func isCollapsedKeyboardFrame(_ frame: CGRect) -> Bool {
        frame.height <= accessoryOnlyHeight + 1
    }

    /// Only a real software keyboard re-arms the heal. The frame is measured on screen, so the
    /// hide notification (parked below the screen) doesn't count, and a collapsed keyboard that
    /// happens to be taller than this view (the input assistant bar a hardware keyboard shows,
    /// safe-area padding) doesn't either. Frames produced by a heal's own cycle are ignored, or
    /// the heal would re-arm itself.
    private func noteKeyboardEndFrame(_ endFrame: CGRect) {
        lastKeyboardEndFrame = endFrame
        guard !isHealing, let window else { return }
        let onScreenHeight = endFrame.intersection(window.screen.bounds).height
        if onScreenHeight > accessoryOnlyHeight + Self.fullKeyboardAllowance {
            healsSinceLastFullKeyboard = 0
        }
    }

    /// A collapsed keyboard is at most this much taller than this view (input assistant bar, safe
    /// area); anything taller on screen is the software keyboard proper.
    private static let fullKeyboardAllowance: CGFloat = 100

    // MARK: - Stranded accessory

    /// The keyboard end frame from the latest notification, in screen coordinates.
    private var lastKeyboardEndFrame: CGRect?
    /// Set between the will- and did-change-frame notifications.
    private var isKeyboardAnimating = false
    private var pendingHealCheck: DispatchWorkItem?
    /// Set for the duration of a first-responder cycle, including the keyboard notifications it
    /// produces afterwards; see `cycleFirstResponder()`.
    private var isHealing = false
    private var healingTimeout: DispatchWorkItem?
    /// A collapse gets one heal at most; the count resets whenever a full keyboard shows.
    private var healsSinceLastFullKeyboard = 0
    /// Belt and braces against a frame sequence the gate above doesn't anticipate: heals never
    /// run back to back, and a burst of them trips the breaker below for good.
    private var lastHealDate = Date.distantPast
    private static let minimumHealInterval: TimeInterval = 1
    /// When the recent heals happened. A user pressing the dismiss key heals once every few
    /// seconds at most; anything denser is the heal chasing its own tail (a TestFlight tester saw
    /// the toolbars flash and the composer resize in a loop with a hardware keyboard attached to
    /// an iPad Pro). Once tripped, this accessory view stops healing for the rest of its life;
    /// the worst case is the gap the heal exists to close.
    private var recentHealDates: [Date] = []
    private var isHealBreakerTripped = false
    private static let healBreakerLimit = 3
    private static let healBreakerWindow: TimeInterval = 15

    /// How far above its reported position this view is sitting, or `nil` when the check doesn't
    /// apply (keyboard not collapsed, not on screen, text view not first responder).
    ///
    /// On iPad, when the keyboard host last laid out the input views with the software keyboard
    /// up and then collapses to accessory-only (the keyboard's own dismiss key), it keeps the
    /// shortcuts bar's slot reserved beneath this view. The keyboard notification still reports
    /// the collapsed keyboard flush with the screen bottom, so the only tell is this view's real
    /// window frame disagreeing with it.
    ///
    /// Both frames are compared in screen coordinates: the keyboard notification reports in
    /// screen space, and this view's window only coincides with the screen when the app fills it
    /// (not in Stage Manager or Split View).
    private var strandedOffset: CGFloat? {
        guard
            let window,
            let textView, textView.isFirstResponder,
            let keyboardFrame = lastKeyboardEndFrame,
            keyboardFrame.minY < window.screen.bounds.maxY - 1,
            isCollapsedKeyboardFrame(keyboardFrame)
            else { return nil }
        let actual = window.convert(convert(bounds, to: nil), to: window.screen.coordinateSpace)
        return keyboardFrame.maxY - actual.maxY
    }

    private static let strandedThreshold: CGFloat = 24

    override func layoutSubviews() {
        super.layoutSubviews()
        // The did-change-frame notification runs its own check once the keyboard settles.
        if !isKeyboardAnimating {
            scheduleHealCheck(after: 0.15)
        }
    }

    /// Keyboard animations pass through transient frames, so the check waits for the layout to
    /// settle and re-reads the frame before acting.
    private func scheduleHealCheck(after delay: TimeInterval) {
        pendingHealCheck?.cancel()
        let check = DispatchWorkItem { [weak self] in
            guard
                let self, !self.isHealing,
                let offset = self.strandedOffset, offset > Self.strandedThreshold
                else { return }
            self.healStrandedAccessory()
        }
        pendingHealCheck = check
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: check)
    }

    /// Re-docks a stranded accessory. Nothing public moves it in place (`reloadInputViews()`
    /// included); presenting the keyboard afresh is what rebuilds the host without the reserved
    /// slot.
    ///
    /// With a hardware keyboard connected there's nothing to heal: the collapsed keyboard, input
    /// assistant bar included, is the steady state, and cycling the first responder just makes
    /// the toolbars flash and the composer resize, over and over.
    private func healStrandedAccessory() {
        guard
            !isHealing,
            !isHealBreakerTripped,
            !isHardwareKeyboardConnected,
            healsSinceLastFullKeyboard == 0,
            Date().timeIntervalSince(lastHealDate) > Self.minimumHealInterval
            else { return }

        let now = Date()
        recentHealDates = recentHealDates.filter { now.timeIntervalSince($0) < Self.healBreakerWindow }
        recentHealDates.append(now)
        if recentHealDates.count >= Self.healBreakerLimit {
            isHealBreakerTripped = true
            return
        }

        healsSinceLastFullKeyboard += 1
        lastHealDate = now
        cycleFirstResponder()
    }

    /// Resigns and re-becomes first responder without losing the selection.
    ///
    /// The keyboard notifications this produces land asynchronously, so the healing state stays
    /// on until the show notification settles (`keyboardDidChangeFrame`) or, if that never
    /// reaches this view, shortly after. Otherwise the cycle's own frames would count as a fresh
    /// collapse and schedule another heal.
    private func cycleFirstResponder() {
        guard let textView, !isHealing else { return }
        isHealing = true
        let selection = textView.selectedTextRange
        UIView.performWithoutAnimation {
            textView.resignFirstResponder()
            textView.becomeFirstResponder()
            textView.selectedTextRange = selection
        }
        syncKeyboardToggle()

        healingTimeout?.cancel()
        let timeout = DispatchWorkItem { [weak self] in self?.finishHealing() }
        healingTimeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: timeout)
    }

    private func finishHealing() {
        guard isHealing else { return }
        healingTimeout?.cancel()
        healingTimeout = nil
        isHealing = false
    }

    /// Matches the toggle's glyph to the text view's actual state. The keyboard can change under
    /// us (the legacy smilie keyboard replaces the input view; the composer resets it when it
    /// disappears), and every such change reinstalls this accessory view.
    private var canToggleKeyboard: Bool {
        !isHardwareKeyboardConnected
    }

    private func syncKeyboardToggle() {
        let minimizedByUs = textView?.isKeyboardMinimized ?? false
        modernToolbar.isKeyboardMinimized = minimizedByUs || isKeyboardMinimizedBySystem
        modernToolbar.isKeyboardToggleEnabled = canToggleKeyboard
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            syncKeyboardToggle()
        }
    }
}

// MARK: - Audio Feedback

extension CompositionToolbarContainer: UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool {
        return true
    }
}
