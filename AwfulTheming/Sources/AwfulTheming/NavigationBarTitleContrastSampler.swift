//  NavigationBarTitleContrastSampler.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// Colours a navigation bar title black or white from the page beneath it once the iOS 26
/// glass bar has gone transparent, the way the system colours its glass bar buttons.
///
/// The system can't do this for a title. Bar buttons adapt because their glass platter samples
/// the pixels under it, whereas a title (or any platter-less bar item) takes the trait of the
/// bar's content view, which UIKit seeds from the scroll view beneath and then only ever
/// darkens over dark content — so in a dark theme it never goes black over light content.
/// (Verified on iOS 26 by logging the trait chain; pinning `overrideUserInterfaceStyle` on the
/// bar, the navigation controller or the screen changes nothing, and neither does an opaque web
/// view painting its own background.) So the screen samples a strip of the page under the
/// title itself, at most a few times a second, and decides with hysteresis so a busy image
/// doesn't flicker it. A decided flip waits `flipDelay` before it lands, and is dropped if the
/// content moves back meanwhile, so the title changes at about the pace the system's bar
/// buttons do rather than snapping ahead of them.
///
/// Only the web-content screens use this (posts, a message, the rap sheet); list screens keep
/// the theme's colours via the navigation controller's appearance.
///
/// Call `sampleIfNeeded()` from scroll events while the bar is transparent and `reset()`
/// otherwise; the label's colour is set here, and `color` is what the screen passes to
/// `UINavigationItem.updateTitleLabelTextColor` until the next capture lands.
@MainActor public final class NavigationBarTitleContrastSampler {
    /// Measures the mean relative luminance (0 dark … 1 light) of the content within a rect in
    /// `sourceView`'s coordinates, composited over the backdrop colour, or nil if it couldn't.
    public typealias Sample = @MainActor (_ rect: CGRect, _ backdrop: UIColor?, _ completion: @escaping @MainActor (CGFloat?) -> Void) -> Void

    private weak var sourceView: UIView?
    private let sample: Sample
    private let titleLabel: () -> UILabel?
    private let backdrop: () -> UIColor?

    /// The colour the content beneath the title currently calls for; nil until the first
    /// capture after `reset()` has landed.
    public private(set) var color: UIColor?

    /// Minimum time between captures.
    private static let interval: CFTimeInterval = 0.1
    /// How long to wait for the capture before assuming its completion is never coming
    /// (e.g. the web content process went away mid-capture) and allowing the next one.
    private static let captureTimeout: CFTimeInterval = 1
    /// How long after the first capture following `reset()` to capture once more: a theme
    /// change restyles the page asynchronously, so the first capture can still see the old
    /// background, and nothing scrolls to trigger another.
    private static let settleDelay: CFTimeInterval = 0.35
    /// How long a decided flip waits before it lands. The system's glass bar buttons ease into
    /// a new colour rather than snapping, so the title holds back to change alongside them.
    private static let flipDelay: CFTimeInterval = 0.2
    /// The cross-dissolve when a flip lands.
    private static let flipDuration: TimeInterval = 0.2

    private var lastSampleTime: CFTimeInterval = 0
    private var trailing: DispatchWorkItem?
    private var settle: DispatchWorkItem?
    private var pendingFlip: DispatchWorkItem?
    private var pendingColor: UIColor?
    private var isCapturing = false
    private var wantsAnotherCapture = false
    private var needsSettleCapture = false
    /// Identifies the capture in flight, so the completion of one abandoned by `reset()` or the
    /// timeout is ignored.
    private var captureGeneration = 0

    /// `titleLabel` and `backdrop` are looked up per capture: the label can be re-hosted, and
    /// the theme (whose page background shows through the transparent web view) can change.
    /// `sourceView` is what `sample`'s rect is expressed in, typically the web view's container.
    public init(sourceView: UIView, sample: @escaping Sample, titleLabel: @escaping () -> UILabel?, backdrop: @escaping () -> UIColor?) {
        self.sourceView = sourceView
        self.sample = sample
        self.titleLabel = titleLabel
        self.backdrop = backdrop
    }

    /// Captures now if the last capture is old enough, otherwise once the interval is up, so a
    /// burst of scroll events costs at most one capture per interval and always ends with one
    /// for the final position.
    public func sampleIfNeeded() {
        let elapsed = CACurrentMediaTime() - lastSampleTime
        if elapsed >= Self.interval {
            performSample()
        } else if trailing == nil {
            let work = DispatchWorkItem { [weak self] in
                self?.trailing = nil
                self?.performSample()
            }
            trailing = work
            DispatchQueue.main.asyncAfter(deadline: .now() + (Self.interval - elapsed), execute: work)
        }
    }

    /// Forgets the sampled colour and abandons any capture in flight or flip pending: the bar
    /// has gone opaque again, or the page is about to change under the title.
    public func reset() {
        trailing?.cancel()
        trailing = nil
        settle?.cancel()
        settle = nil
        cancelPendingFlip()
        captureGeneration += 1
        isCapturing = false
        wantsAnotherCapture = false
        needsSettleCapture = true
        color = nil
    }

    private func performSample() {
        lastSampleTime = CACurrentMediaTime()
        if isCapturing {
            wantsAnotherCapture = true
            return
        }
        guard let sourceView, let label = titleLabel(), label.window != nil else { return }
        let rect = label.convert(label.bounds, to: sourceView)
        isCapturing = true
        captureGeneration += 1
        let generation = captureGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.captureTimeout) { [weak self] in
            guard let self, self.captureGeneration == generation else { return }
            self.captureGeneration += 1
            self.finishCapture()
        }
        sample(rect, backdrop()) { [weak self] luminance in
            guard let self, self.captureGeneration == generation else { return }
            if let luminance {
                self.apply(luminance: luminance)
            }
            self.finishCapture()
        }
    }

    private func finishCapture() {
        isCapturing = false
        if wantsAnotherCapture {
            wantsAnotherCapture = false
            sampleIfNeeded()
        } else if needsSettleCapture {
            needsSettleCapture = false
            let work = DispatchWorkItem { [weak self] in
                self?.settle = nil
                self?.performSample()
            }
            settle = work
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.settleDelay, execute: work)
        }
    }

    private func apply(luminance: CGFloat) {
        // Hysteresis: once decided, the content has to move well past the midpoint to flip.
        let next: UIColor
        switch color {
        case .black?:
            next = luminance < 0.4 ? .white : .black
        case .white?:
            next = luminance > 0.6 ? .black : .white
        default:
            next = luminance > 0.5 ? .black : .white
        }
        guard next != color else {
            // The content moved back before a pending flip landed: never mind.
            cancelPendingFlip()
            return
        }
        guard pendingColor != next else { return }
        cancelPendingFlip()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingFlip = nil
            self.pendingColor = nil
            self.color = next
            guard let label = self.titleLabel() else { return }
            UIView.transition(with: label, duration: Self.flipDuration, options: [.transitionCrossDissolve, .beginFromCurrentState]) {
                label.textColor = next
            }
        }
        pendingColor = next
        pendingFlip = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.flipDelay, execute: work)
    }

    private func cancelPendingFlip() {
        pendingFlip?.cancel()
        pendingFlip = nil
        pendingColor = nil
    }
}
