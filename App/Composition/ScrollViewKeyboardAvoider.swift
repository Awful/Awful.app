//  ScrollViewKeyboardAvoider.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// Sets a scroll view's bottom insets to avoid the keyboard.
final class ScrollViewKeyboardAvoider {
    private var observer: NSObjectProtocol?
    private weak var scrollView: UIScrollView?

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
        let options = UIView.AnimationOptions(rawValue: UInt(rawCurve) << 16)
        apply(keyboardScreenFrame: screenFrame, duration: duration, options: options, attempt: 0)
    }

    private func apply(keyboardScreenFrame screenFrame: CGRect, duration: TimeInterval, options: UIView.AnimationOptions, attempt: Int) {
        guard let scrollView else { return }

        func retry() {
            // The keyboard frame notification won't fire again on its own; keep trying until the
            // view hierarchy settles (a modal transition runs ~0.4s).
            guard attempt < 10 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.apply(keyboardScreenFrame: screenFrame, duration: 0, options: options, attempt: attempt + 1)
            }
        }

        guard let window = scrollView.window else { return retry() }

        let localFrame = scrollView.superview!.convert(screenFrame, from: window.screen.coordinateSpace)

        // If this notification fires mid-transition (e.g. the image picker is still animating its
        // dismissal), an ancestor view carries a transient transform that corrupts the conversion,
        // and the resulting inset silently sticks at a bogus value. A converted size that doesn't
        // match the keyboard's is the tell; wait for the hierarchy to settle instead.
        if abs(localFrame.width - screenFrame.width) > 1 || abs(localFrame.height - screenFrame.height) > 1 {
            return retry()
        }

        let intersection = localFrame.intersection(scrollView.frame)
        let bottomInset = intersection.isNull ? 0 : intersection.height

        UIView.animate(withDuration: duration, delay: 0, options: options, animations: {
            scrollView.contentInset.bottom = bottomInset
            scrollView.verticalScrollIndicatorInsets.bottom = bottomInset
        }, completion: { [weak self] _ in
            self?.onInsetsChanged?()
        })
    }
}
