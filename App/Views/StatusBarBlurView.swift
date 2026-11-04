//  StatusBarBlurView.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// A light blur that fades out towards its bottom edge, for under the status bar. Sized to the status bar, the fade finishes just below the base of the Dynamic Island.
///
/// Set `overrideUserInterfaceStyle` to choose its light or dark tint.
final class StatusBarBlurView: UIView {
    private let effectView = UIVisualEffectView(effect: nil)
    private let fade = CAGradientLayer()

    /// How far towards the full blur the view goes, from 0 (none) to 1 (full). The full blur reads as much stronger than the system's scroll edge effect, which builds up gradually.
    private static let blurStrength: CGFloat = 0.1

    /// Holds the blur at `blurStrength`. UIKit has no API for a weaker blur, but a paused animator from no effect to the full blur renders the blur at its fraction complete.
    private var animator: UIViewPropertyAnimator?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        fade.colors = [UIColor.black.cgColor, UIColor.black.cgColor, UIColor.clear.cgColor]
        fade.locations = [0, 0.6, 1]
        effectView.layer.mask = fade
        addSubview(effectView)

        // The paused animator captured the blur in the light/dark of the moment.
        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
                self.applyBlur()
            }
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        // UIKit raises an exception if an active animator is deallocated.
        MainActor.assumeIsolated {
            animator?.stopAnimation(true)
        }
    }

    /// UIKit drops a paused animator's partial effect when the view leaves its window, so the blur is set up again each time the view goes into one.
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            applyBlur()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        effectView.frame = bounds
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fade.frame = effectView.bounds
        CATransaction.commit()
    }

    private func applyBlur() {
        animator?.stopAnimation(true)
        effectView.effect = nil
        let animator = UIViewPropertyAnimator(duration: 1, curve: .linear) { [effectView] in
            effectView.effect = UIBlurEffect(style: .regular)
        }
        animator.pausesOnCompletion = true
        animator.fractionComplete = Self.blurStrength
        self.animator = animator
    }
}
