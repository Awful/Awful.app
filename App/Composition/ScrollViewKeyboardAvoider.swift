//  ScrollViewKeyboardAvoider.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// Sets a scroll view's bottom insets to avoid the keyboard.
final class ScrollViewKeyboardAvoider {
    private var observers: [NSObjectProtocol] = []
    private weak var scrollView: UIScrollView?

    /// The most recent keyboard end frame, in screen coordinates, so `reapply()` can recompute the
    /// inset once the view hierarchy has settled. A hidden keyboard reports an off-screen frame,
    /// which naturally yields an inset of zero.
    private var lastKeyboardScreenFrame: CGRect?

    /// The inset the last keyboard notification decided on. `reapply()` leaves an in-flight
    /// keyboard animation alone when a layout pass agrees with it.
    private var targetBottomInset: CGFloat?

    /// Called after the insets have animated to match a new keyboard frame.
    var onInsetsChanged: (() -> Void)?

    init(_ scrollView: UIScrollView) {
        self.scrollView = scrollView
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: OperationQueue.main) { [unowned self] note in
            self.keyboardWillChangeFrame(note)
        })
        observers.append(center.addObserver(forName: UIResponder.keyboardDidChangeFrameNotification, object: nil, queue: OperationQueue.main) { [unowned self] note in
            self.keyboardDidChangeFrame(note)
        })
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    private func keyboardWillChangeFrame(_ note: Notification) {
        guard
            let userInfo = note.userInfo,
            var screenFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
            let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval,
            let rawCurve = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int
            else { return }
        // Another window's keyboard (iPad multitasking) says nothing about ours.
        if let isLocal = userInfo[UIResponder.keyboardIsLocalUserInfoKey] as? Bool, !isLocal { return }
        if isSceneInBackground { return }

        // Coming back from the background, iOS posts the right keyboard frame and then one that
        // leaves out the input accessory view, though the accessory toolbars stay on screen on
        // top of it. That frame starts exactly where the accessory ends. Count the accessory back
        // in, or the inset drops by the toolbars' height (hiding the caret line behind them) and
        // the text jumps when it's corrected.
        if let accessory = dockedAccessoryScreenFrame(keyboardScreenFrame: screenFrame),
           abs(screenFrame.minY - accessory.maxY) < 1
        {
            screenFrame = CGRect(x: screenFrame.minX, y: accessory.minY, width: screenFrame.width, height: screenFrame.maxY - accessory.minY)
        }

        lastKeyboardScreenFrame = screenFrame
        let options = UIView.AnimationOptions(rawValue: UInt(rawCurve) << 16)
        apply(keyboardScreenFrame: screenFrame, duration: duration, options: options, attempt: 0)
    }

    /// A safety net for a frame that leaves out the input accessory view in some way the check in
    /// `keyboardWillChangeFrame` doesn't recognize. Once the keyboard has settled, the accessory
    /// view's real position is the tiebreaker: the keyboard can't start below it.
    private func keyboardDidChangeFrame(_ note: Notification) {
        if let isLocal = note.userInfo?[UIResponder.keyboardIsLocalUserInfoKey] as? Bool, !isLocal { return }
        if isSceneInBackground { return }
        guard
            let reported = lastKeyboardScreenFrame,
            let accessory = dockedAccessoryScreenFrame(keyboardScreenFrame: reported),
            accessory.minY < reported.minY - 0.5
            else { return }

        lastKeyboardScreenFrame = CGRect(x: reported.minX, y: accessory.minY, width: reported.width, height: reported.maxY - accessory.minY)
        reapply()
    }

    /// In the background the keyboard reports frames, and lays out the accessory view, for the app
    /// switcher snapshot (scaled down, or a different height). Nothing is on screen to keep clear,
    /// and acting on them scrolls the text, which then visibly jumps back on return, when iOS
    /// reports the real frame again.
    private var isSceneInBackground: Bool {
        scrollView?.window?.windowScene?.activationState == .background
    }

    /// The scroll view's input accessory view in screen coordinates, when the scroll view is first
    /// responder and `keyboardScreenFrame` is a keyboard docked to the bottom of the screen. A
    /// floating or undocked iPad keyboard reports something else entirely, and a hidden one is
    /// off screen, so neither says anything about where the accessory should be.
    private func dockedAccessoryScreenFrame(keyboardScreenFrame: CGRect) -> CGRect? {
        guard
            let scrollView, scrollView.isFirstResponder,
            let accessory = scrollView.inputAccessoryView,
            let window = accessory.window
            else { return nil }
        let screenBounds = window.screen.bounds
        guard keyboardScreenFrame.height > 0, abs(keyboardScreenFrame.maxY - screenBounds.maxY) < 1 else { return nil }

        let accessoryFrame = window.convert(accessory.convert(accessory.bounds, to: window), to: window.screen.coordinateSpace)
        guard accessoryFrame.height > 0, accessoryFrame.minY >= screenBounds.minY else { return nil }
        return accessoryFrame
    }

    /// Recomputes the inset for the last known keyboard frame, without animating. Safe to call
    /// from `viewDidAppear` and `viewDidLayoutSubviews`: it does nothing unless the hierarchy is
    /// settled and the answer differs from what's already applied.
    ///
    /// The keyboard notification typically arrives while the sheet is still sliding in (the text
    /// view asks for the keyboard in `viewWillAppear`), so the inset computed then can be wrong
    /// and nothing fires again to correct it. This is the correction.
    func reapply() {
        guard
            let scrollView,
            let screenFrame = lastKeyboardScreenFrame,
            let bottomInset = bottomInset(for: screenFrame)
            else { return }
        if let target = targetBottomInset, abs(target - bottomInset) < 0.5 { return }
        if abs(scrollView.contentInset.bottom - bottomInset) < 0.5 { return }

        targetBottomInset = bottomInset
        scrollView.contentInset.bottom = bottomInset
        scrollView.verticalScrollIndicatorInsets.bottom = bottomInset
        onInsetsChanged?()
    }

    /// The scroll view's bottom inset that keeps its content clear of the keyboard, or `nil` when
    /// the view hierarchy can't be trusted to convert the keyboard frame yet.
    private func bottomInset(for screenFrame: CGRect) -> CGFloat? {
        guard
            let scrollView,
            let window = scrollView.window,
            let superview = scrollView.superview
            else { return nil }

        let localFrame = superview.convert(screenFrame, from: window.screen.coordinateSpace)

        // If this fires mid-transition (e.g. the image picker is still animating its dismissal),
        // an ancestor view carries a transient transform that corrupts the conversion, and the
        // resulting inset silently sticks at a bogus value. A converted size that doesn't match
        // the keyboard's is the tell; wait for the hierarchy to settle instead.
        if abs(localFrame.width - screenFrame.width) > 1 || abs(localFrame.height - screenFrame.height) > 1 {
            return nil
        }

        let intersection = localFrame.intersection(scrollView.frame)
        return intersection.isNull ? 0 : intersection.height
    }

    private func apply(keyboardScreenFrame screenFrame: CGRect, duration: TimeInterval, options: UIView.AnimationOptions, attempt: Int) {
        guard let scrollView else { return }

        func retry() {
            // The keyboard frame notification won't fire again on its own; keep trying until the
            // view hierarchy settles (a modal transition runs ~0.4s). `reapply()` covers the case
            // where this gives up.
            guard attempt < 10 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.apply(keyboardScreenFrame: screenFrame, duration: 0, options: options, attempt: attempt + 1)
            }
        }

        // A newer notification supersedes this retry chain.
        guard screenFrame == lastKeyboardScreenFrame else { return }

        guard let bottomInset = bottomInset(for: screenFrame) else { return retry() }

        targetBottomInset = bottomInset
        UIView.animate(withDuration: duration, delay: 0, options: options, animations: {
            scrollView.contentInset.bottom = bottomInset
            scrollView.verticalScrollIndicatorInsets.bottom = bottomInset
        }, completion: { [weak self] _ in
            self?.onInsetsChanged?()
        })
    }
}
