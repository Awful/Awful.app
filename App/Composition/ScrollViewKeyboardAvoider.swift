//  ScrollViewKeyboardAvoider.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// Sets a scroll view's bottom insets to avoid the keyboard.
final class ScrollViewKeyboardAvoider {
    private var observer: NSObjectProtocol?
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
        observer = NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: OperationQueue.main) { [unowned self] note in
            self.keyboardWillChangeFrame(note)
        }
    }

    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func keyboardWillChangeFrame(_ note: Notification) {
        guard
            let userInfo = note.userInfo,
            let screenFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
            let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval,
            let rawCurve = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int
            else { return }
        // Another window's keyboard (iPad multitasking) says nothing about ours.
        if let isLocal = userInfo[UIResponder.keyboardIsLocalUserInfoKey] as? Bool, !isLocal { return }

        lastKeyboardScreenFrame = screenFrame
        let options = UIView.AnimationOptions(rawValue: UInt(rawCurve) << 16)
        apply(keyboardScreenFrame: screenFrame, duration: duration, options: options, attempt: 0)
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
