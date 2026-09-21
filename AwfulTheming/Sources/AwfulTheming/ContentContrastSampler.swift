//  ContentContrastSampler.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// Decides black or white from the page beneath a region of the screen once the iOS 26 glass
/// bar has gone transparent, the way the system colours its glass bar buttons. The posts page
/// uses one for the navigation bar title and one for the status bar while immersive mode is on.
///
/// The system can't do this for a title, or for the status bar. Bar buttons adapt because their
/// glass platter samples the pixels under it, whereas a title (or any platter-less bar item)
/// takes the trait of the bar's content view, which UIKit seeds from the scroll view beneath and
/// then only ever darkens over dark content — so in a dark theme it never goes black over light
/// content. (Verified on iOS 26 by logging the trait chain; pinning `overrideUserInterfaceStyle`
/// on the bar, the navigation controller or the screen changes nothing, and neither does an
/// opaque web view painting its own background.) The status bar's `.default` style likewise
/// follows a trait rather than the pixels. So the screen samples a strip of the page under the
/// region, at most a few times a second, and decides with hysteresis so a busy image doesn't
/// flicker it. A decided flip waits `flipDelay` before it lands, and is dropped if the content
/// moves back meanwhile, so the colour changes at about the pace the system's bar buttons do
/// rather than snapping ahead of them.
///
/// Only the posts page in immersive mode uses this: there the title and status bar sit over the
/// bare page (the bar's own blur is faint, and the bar slides away altogether). Elsewhere the
/// system's soft edge effect blurs the page under the transparent bar, and the theme's mode
/// colour reads fine over it, so the other screens keep the theme's colours.
///
/// Call `sampleIfNeeded()` from scroll events while the bar is transparent and `reset()`
/// otherwise. `onColorChange` is told each time `color` changes, including back to nil on
/// `reset()`; the title and status bar conveniences use it to recolour the label and to tell the
/// navigation controller (`UIViewController.contentContrastDidChange()`).
@MainActor public final class ContentContrastSampler {
    /// Measures the mean relative luminance (0 dark … 1 light) of the content within a rect in
    /// `sourceView`'s coordinates, composited over the backdrop colour, or nil if it couldn't.
    public typealias Sample = @MainActor (_ rect: CGRect, _ backdrop: UIColor?, _ completion: @escaping @MainActor (CGFloat?) -> Void) -> Void

    private weak var sourceView: UIView?
    private let sample: Sample
    private let region: () -> CGRect?
    private let backdrop: () -> UIColor?
    private let onColorChange: (UIColor?) -> Void

    /// The colour the content beneath the region currently calls for (`.black` or `.white`);
    /// nil until the first capture after `reset()` has landed.
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
    public static let flipDuration: TimeInterval = 0.2

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

    /// `region` and `backdrop` are looked up per capture: the sampled view can be re-hosted or
    /// move, and the theme (whose page background shows through the transparent web view) can
    /// change. `region` is in `sourceView`'s coordinates (what `sample`'s rect is expressed in,
    /// typically the web view's container) and returns nil to skip a capture.
    public init(
        sourceView: UIView,
        sample: @escaping Sample,
        region: @escaping () -> CGRect?,
        backdrop: @escaping () -> UIColor?,
        onColorChange: @escaping (UIColor?) -> Void
    ) {
        self.sourceView = sourceView
        self.sample = sample
        self.region = region
        self.backdrop = backdrop
        self.onColorChange = onColorChange
    }

    /// Samples the page beneath the navigation bar title (`titleLabel`, looked up per capture
    /// since it can be re-hosted) and cross-dissolves the label's text colour when it decides,
    /// then tells `viewController`'s navigation controller (`contentContrastDidChange()`), which
    /// reads the result through `NavigationBarScrollTransitioning.navigationBarContentColor`.
    public convenience init(
        sourceView: UIView,
        sample: @escaping Sample,
        titleLabel: @escaping () -> UILabel?,
        backdrop: @escaping () -> UIColor?,
        titleOf viewController: UIViewController
    ) {
        self.init(
            sourceView: sourceView,
            sample: sample,
            region: { [weak sourceView] in
                guard let sourceView, let label = titleLabel(), label.window != nil else { return nil }
                return label.convert(label.bounds, to: sourceView)
            },
            backdrop: backdrop,
            onColorChange: { [weak viewController] color in
                if let color, let label = titleLabel() {
                    UIView.transition(with: label, duration: Self.flipDuration, options: [.transitionCrossDissolve, .beginFromCurrentState]) {
                        label.textColor = color
                    }
                }
                viewController?.contentContrastDidChange()
            }
        )
    }

    /// Samples the page beneath the status bar and tells `viewController`'s navigation
    /// controller when it decides (`contentContrastDidChange()`), which reads the result through
    /// `NavigationBarScrollTransitioning.statusBarContentColor` and restyles the status bar.
    /// `onColorChange` is then told too, for anything else the screen draws in the status bar's
    /// strip.
    public convenience init(
        sourceView: UIView,
        sample: @escaping Sample,
        backdrop: @escaping () -> UIColor?,
        statusBarOf viewController: UIViewController,
        onColorChange: ((UIColor?) -> Void)? = nil
    ) {
        self.init(
            sourceView: sourceView,
            sample: sample,
            region: { [weak sourceView] in
                guard let sourceView else { return nil }
                return Self.statusBarRegion(in: sourceView)
            },
            backdrop: backdrop,
            onColorChange: { [weak viewController] color in
                viewController?.contentContrastDidChange()
                onColorChange?(color)
            }
        )
    }

    /// The status bar's frame in `view`'s coordinates, or nil if `view` isn't in a window or the
    /// status bar has no height. Spans the window: a sampler's `sample` clips it to its content.
    private static func statusBarRegion(in view: UIView) -> CGRect? {
        guard let window = view.window else { return nil }
        let height = window.windowScene?.statusBarManager?.statusBarFrame.height ?? window.safeAreaInsets.top
        guard height > 0 else { return nil }
        let frame = CGRect(x: 0, y: 0, width: window.bounds.width, height: height)
        return window.convert(frame, to: view)
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
    /// has gone opaque again, or the page is about to change under the region.
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
        if color != nil {
            color = nil
            onColorChange(nil)
        }
    }

    private func performSample() {
        lastSampleTime = CACurrentMediaTime()
        if isCapturing {
            wantsAnotherCapture = true
            return
        }
        guard sourceView != nil, let rect = region() else { return }
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
            self.onColorChange(next)
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
