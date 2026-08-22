//  TiltScrollManager.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulExtensions
import AwfulSettings
import Combine
import CoreMotion
import UIKit

// MARK: - TiltScrollManager

/// Scrolls the posts page in response to tilting the device toward or away
/// from the user. Samples device motion on a display link and drives the
/// scroll view's content offset at a velocity proportional to tilt beyond a
/// dead zone. Enabled via `Settings.tiltScrollEnabled`; speed scales with
/// `Settings.tiltScrollSensitivity`.
@MainActor
public final class TiltScrollManager: NSObject {

    // MARK: - Constants

    /// Tilt within this angle of the neutral reference does nothing.
    private static let deadZoneRadians: CGFloat = 2.5 * .pi / 180
    /// Tilt this far past the dead zone reaches maximum scroll speed.
    private static let rampRadians: CGFloat = 15 * .pi / 180
    /// Exponent applied to the normalized tilt for finer control near zero.
    private static let responseExponent: CGFloat = 1.5
    /// Maximum scroll speed (points/second) at minimum sensitivity.
    private static let minMaxVelocity: CGFloat = 250
    /// Maximum scroll speed (points/second) at maximum sensitivity.
    private static let maxMaxVelocity: CGFloat = 1500
    /// Low-pass time constant for the tilt angle, to filter out hand jitter.
    private static let angleFilterTimeConstant: TimeInterval = 0.1
    /// Time constant for the neutral reference to drift toward the current
    /// angle while inside the dead zone, following gradual posture changes.
    private static let neutralAdaptTimeConstant: TimeInterval = 6.0

    /// Apple recommends a single CMMotionManager per app; several
    /// PostsPageViewControllers can exist in navigation stacks at once.
    private static let motionManager = CMMotionManager()
    /// Number of TiltScrollManager instances currently engaged; device motion
    /// updates stop when this drops to zero.
    private static var engagedCount = 0

    // MARK: - Dependencies

    private weak var scrollView: UIScrollView?

    public func configure(scrollView: UIScrollView) {
        self.scrollView = scrollView
    }

    // MARK: - Configuration

    @FoilDefaultStorage(Settings.tiltScrollEnabled) private var tiltScrollEnabled
    @FoilDefaultStorage(Settings.tiltScrollInverted) private var tiltScrollInverted
    @FoilDefaultStorage(Settings.tiltScrollSensitivity) private var tiltScrollSensitivity
    private var cancellables: Set<AnyCancellable> = []

    // MARK: - State

    private var isViewVisible = false
    private var isUserInteracting = false
    private var isEngaged = false
    private var displayLink: CADisplayLink?
    /// CADisplayLink retains its target, so aim it at a weak-forwarding proxy to keep the run loop
    /// from retaining this manager (which would also keep the accelerometer running).
    private let proxy = DisplayLinkProxy()
    /// The tilt angle considered "at rest". `nil` means capture on next sample.
    private var neutralAngle: CGFloat?
    private var filteredAngle: CGFloat?
    private var lastInterfaceOrientation: UIInterfaceOrientation = .portrait

    public override init() {
        super.init()

        proxy.target = self

        $tiltScrollEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateEngagement() }
            .store(in: &cancellables)

        let notifications: [Notification.Name] = [
            UIApplication.didBecomeActiveNotification,
            UIApplication.willResignActiveNotification,
            UIAccessibility.voiceOverStatusDidChangeNotification,
            UIAccessibility.reduceMotionStatusDidChangeNotification,
        ]
        for name in notifications {
            NotificationCenter.default.publisher(for: name)
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.updateEngagement() }
                .store(in: &cancellables)
        }
    }

    // MARK: - Lifecycle

    public func viewDidAppear() {
        isViewVisible = true
        updateEngagement()
    }

    public func viewWillDisappear() {
        isViewVisible = false
        updateEngagement()
    }

    deinit {
        // If appearance callbacks never delivered a final `viewWillDisappear()`, make sure this
        // instance's engagement (and its share of the device-motion updates) still winds down.
        displayLink?.invalidate()
        if isEngaged {
            // Owners are view controllers, so deallocation happens on the main thread — but deinit
            // is formally nonisolated, so assert isolation to reach the shared engagement count.
            MainActor.assumeIsolated {
                Self.engagedCount -= 1
                if Self.engagedCount == 0 {
                    Self.motionManager.stopDeviceMotionUpdates()
                }
            }
        }
    }

    /// Adopts the device's current pose as the new "at rest" zero point, so
    /// scrolling is driven by tilt relative to however the user is holding
    /// the device right now (e.g. lying in bed).
    public func recalibrate() {
        neutralAngle = nil
        filteredAngle = nil
    }

    // MARK: - Scroll view interaction

    public func handleScrollViewWillBeginDragging() {
        isUserInteracting = true
    }

    public func handleScrollViewDidEndDragging(willDecelerate: Bool) {
        if !willDecelerate {
            isUserInteracting = false
        }
    }

    public func handleScrollViewDidEndDecelerating() {
        isUserInteracting = false
    }

    // MARK: - Engagement

    private var shouldBeEngaged: Bool {
        tiltScrollEnabled
        && isViewVisible
        && UIApplication.shared.applicationState == .active
        && !UIAccessibility.isVoiceOverRunning
        && !UIAccessibility.isReduceMotionEnabled
    }

    private func updateEngagement() {
        let shouldEngage = shouldBeEngaged
        guard shouldEngage != isEngaged else { return }
        isEngaged = shouldEngage

        if shouldEngage {
            Self.engagedCount += 1
            if Self.engagedCount == 1 {
                Self.motionManager.deviceMotionUpdateInterval = 1 / 60
                Self.motionManager.startDeviceMotionUpdates()
            }

            neutralAngle = nil
            filteredAngle = nil

            let link = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.tick(_:)))
            link.add(to: .main, forMode: .common)
            displayLink = link
        } else {
            displayLink?.invalidate()
            displayLink = nil

            Self.engagedCount -= 1
            if Self.engagedCount == 0 {
                Self.motionManager.stopDeviceMotionUpdates()
            }
        }
    }

    // MARK: - Scrolling

    fileprivate func tick(_ link: CADisplayLink) {
        guard let scrollView, let motion = Self.motionManager.deviceMotion else { return }
        let dt = link.targetTimestamp - link.timestamp
        guard dt > 0 else { return }

        // Project gravity onto the interface's up axis. Unlike attitude.pitch,
        // this works in every orientation and stays stable when the device is
        // nearly flat.
        let gravity = motion.gravity
        let orientation = scrollView.window?.windowScene?.interfaceOrientation ?? .portrait
        if orientation != lastInterfaceOrientation {
            lastInterfaceOrientation = orientation
            neutralAngle = nil
            filteredAngle = nil
        }
        let upComponent: Double
        switch orientation {
        case .portraitUpsideDown: upComponent = gravity.y
        case .landscapeLeft: upComponent = -gravity.x
        case .landscapeRight: upComponent = gravity.x
        default: upComponent = -gravity.y
        }
        // 0 = screen vertical; positive = top of device tilted away (toward face up).
        let rawAngle = CGFloat(atan2(-gravity.z, upComponent))

        let filterAlpha = CGFloat(min(1, dt / Self.angleFilterTimeConstant))
        let angle: CGFloat
        if let previous = filteredAngle {
            angle = previous + (rawAngle - previous) * filterAlpha
        } else {
            angle = rawAngle
        }
        filteredAngle = angle

        guard let neutral = neutralAngle else {
            neutralAngle = angle
            return
        }
        let delta = angle - neutral

        if abs(delta) < Self.deadZoneRadians {
            // Follow gradual posture drift, but only while at rest so a
            // deliberate sustained tilt is never adopted as the new neutral.
            let adaptAlpha = CGFloat(min(1, dt / Self.neutralAdaptTimeConstant))
            neutralAngle = neutral + delta * adaptAlpha
            return
        }

        guard !isUserInteracting,
              !scrollView.isTracking,
              !scrollView.isDragging,
              !scrollView.isDecelerating
        else { return }

        let excess = abs(delta) - Self.deadZoneRadians
        let normalized = min(1, excess / Self.rampRadians)
        let maxVelocity = Self.minMaxVelocity
            + (Self.maxMaxVelocity - Self.minMaxVelocity) * CGFloat(tiltScrollSensitivity).clamp(0...1)
        // Tilting the top of the device away scrolls down the page, unless the
        // direction is inverted.
        let direction: CGFloat = (delta > 0 ? 1 : -1) * (tiltScrollInverted ? -1 : 1)
        let velocity = direction * maxVelocity * pow(normalized, Self.responseExponent)

        let minY = -scrollView.adjustedContentInset.top
        let maxY = max(
            scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom,
            minY
        )
        guard maxY > minY else { return }
        let newY = (scrollView.contentOffset.y + velocity * CGFloat(dt)).clamp(minY...maxY)
        guard newY != scrollView.contentOffset.y else { return }
        scrollView.contentOffset = CGPoint(x: scrollView.contentOffset.x, y: newY)
    }
}

/// Weak-forwarding CADisplayLink target, so the run loop's strong reference to the link's target
/// doesn't keep the manager alive.
@MainActor
private final class DisplayLinkProxy: NSObject {
    weak var target: TiltScrollManager?

    @objc func tick(_ link: CADisplayLink) {
        target?.tick(link)
    }
}
