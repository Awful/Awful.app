//  RenderViewPerformance.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import os
import ScrollViewDelegateMultiplexer
import UIKit
import WebKit

/**
 Performance instrumentation for pages of posts.

 Native milestones (fetch, HTML massaging, template render, web view load) are always emitted as signposts, visible in Instruments under the `PostsPerformance` category. In debug builds, launching with `-AwfulPerfProbe YES` also logs each milestone with elapsed time and the app's memory footprint, and injects a probe into the web view that reports paints, dropped frames, image counts and estimated decoded image memory, and network resource timing.

 Stream the output with:

     xcrun simctl spawn booted log stream --level info --predicate 'category == "PostsPerformance"'
 */
enum PostsPerformance {
    static let signposter = OSSignposter(subsystem: Bundle.main.bundleIdentifier!, category: "PostsPerformance")
    static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "PostsPerformance")

    /// Set with the launch argument `-AwfulPerfProbe YES`. Always off in release builds.
    #if DEBUG
    static let isProbeEnabled = UserDefaults.standard.bool(forKey: "AwfulPerfProbe")
    #else
    static let isProbeEnabled = false
    #endif

    /// The app process's physical footprint in megabytes (what Xcode's memory gauge shows). The web content process is separate and not included.
    static func appFootprintMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return -1 }
        return Double(info.phys_footprint) / 1_048_576
    }

    /// Times one page load, from `loadPage` until the page is on screen and its images have settled.
    struct Trace: Sendable {
        let label: String
        private let start = DispatchTime.now().uptimeNanoseconds

        init(label: String) {
            self.label = label
        }

        var elapsedMilliseconds: Int {
            Int((DispatchTime.now().uptimeNanoseconds - start) / 1_000_000)
        }

        func mark(_ milestone: String) {
            signposter.emitEvent("Milestone", "\(label, privacy: .public): \(milestone, privacy: .public)")
            guard isProbeEnabled else { return }
            logger.info("[\(label, privacy: .public)] +\(elapsedMilliseconds)ms \(milestone, privacy: .public) (app footprint \(appFootprintMB(), format: .fixed(precision: 1))MB)")
        }
    }

    #if DEBUG
    static let reportMessageName = "perfReport"

    /// Posted as a Darwin notification, with the page number appended, whenever the probe reports a different page at the top of the viewport (0 for the page first loaded). Lets a UI test follow along without snapshotting the web view's accessibility tree.
    static let topPageNotificationPrefix = "com.awfulapp.Awful.perf.topPage."

    static func announceTopPage(_ page: Int) {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName("\(topPageNotificationPrefix)\(page)" as CFString),
            nil, nil, true)
    }

    /// Injected at document start so it observes the whole load, including first paint.
    static let probeScript = WKUserScript(source: probeSource, injectionTime: .atDocumentStart, forMainFrameOnly: true)

    /// Launching with `-AwfulPerfProbeFrames NO` as well turns off the probe's frame sampling. Sampling runs a `requestAnimationFrame` loop while scrolling, which makes the web content process do a rendering update every frame, so turn it off to measure that process's CPU without the probe's own cost.
    private static let samplesFrames = UserDefaults.standard.object(forKey: "AwfulPerfProbeFrames") == nil
        || UserDefaults.standard.bool(forKey: "AwfulPerfProbeFrames")

    private static let probeSource = #"""
    (function() {
      if (window.AwfulPerf) { return; }
      const sampleFrames = \#(samplesFrames);

      function post(type, data) {
        if (data === null) { return; }
        try {
          window.webkit.messageHandlers.perfReport.postMessage(
            Object.assign({ type: type, t: Math.round(performance.now()) }, data || {}));
        } catch (e) {}
      }

      // The default buffer of 250 entries fills up on image-heavy pages.
      try { performance.setResourceTimingBufferSize(5000); } catch (e) {}

      const perf = window.AwfulPerf = { supported: {} };

      // WebKit ignores unsupported types rather than throwing, so check up front.
      const supportedTypes = PerformanceObserver.supportedEntryTypes || [];
      function observe(type, callback) {
        if (supportedTypes.indexOf(type) === -1) {
          perf.supported[type] = false;
          return;
        }
        try {
          new PerformanceObserver(function(list) { callback(list.getEntries()); })
            .observe({ type: type, buffered: true });
          perf.supported[type] = true;
        } catch (e) {
          perf.supported[type] = false;
        }
      }

      observe('paint', function(entries) {
        entries.forEach(function(e) { post('paint', { name: e.name, start: Math.round(e.startTime) }); });
      });
      observe('largest-contentful-paint', function(entries) {
        const last = entries[entries.length - 1];
        perf.lcp = { start: Math.round(last.startTime), size: last.size, element: last.element ? last.element.tagName : null };
      });
      perf.longTasks = { count: 0, total: 0, max: 0 };
      observe('longtask', function(entries) {
        entries.forEach(function(e) {
          perf.longTasks.count++;
          perf.longTasks.total += e.duration;
          perf.longTasks.max = Math.max(perf.longTasks.max, e.duration);
        });
      });
      observe('layout-shift', function(entries) {
        entries.forEach(function(e) {
          if (frameSession && !e.hadRecentInput) { frameSession.layoutShift += e.value; }
        });
      });
      perf.slowEvents = [];
      observe('event', function(entries) {
        entries.forEach(function(e) {
          if (e.duration >= 100) { perf.slowEvents.push({ name: e.name, duration: Math.round(e.duration) }); }
        });
      });

      // Frame pacing, sampled only while loading and scrolling so the probe itself doesn't keep
      // the page rendering (and burning power) while idle.
      let frameSession = null;
      let frameRequest = 0;
      function tick(timestamp) {
        const s = frameSession;
        if (!s) { return; }
        const gap = s.last ? timestamp - s.last : 0;
        if (s.last) {
          s.frames++;
          if (gap > 20) { s.dropped += Math.max(0, Math.round(gap / (1000 / 60)) - 1); }
          if (gap > 50) { s.longFrames++; }
          s.maxGap = Math.max(s.maxGap, gap);
        }
        s.last = timestamp;
        frameRequest = requestAnimationFrame(tick);
      }
      function startFrames(kind) {
        if (frameSession) { return; }
        frameSession = {
          kind: kind, begin: performance.now(), startY: window.scrollY, frames: 0, dropped: 0, longFrames: 0, maxGap: 0, last: 0,
          shifts: { above: 0, straddling: 0, firstRender: 0, growth: 0, px: 0 }, layoutShift: 0
        };
        // Without frame sampling the session still collects resizes above the viewport.
        if (sampleFrames) { frameRequest = requestAnimationFrame(tick); }
      }
      function stopFrames() {
        const s = frameSession;
        if (!s) { return null; }
        frameSession = null;
        cancelAnimationFrame(frameRequest);
        return {
          kind: s.kind,
          durationMs: Math.round(performance.now() - s.begin),
          distance: Math.round(window.scrollY - s.startY),
          frames: s.frames,
          droppedFrames: s.dropped,
          longFrames: s.longFrames,
          maxFrameGapMs: Math.round(s.maxGap),
          // Posts that changed height while above (or across) the top of the viewport, which moves everything below unless scroll anchoring compensates.
          resizesAboveViewport: s.shifts,
          layoutShiftScore: perf.supported['layout-shift'] ? Math.round(s.layoutShift * 1000) / 1000 : 'unsupported'
        };
      }

      // Watches post heights so a scroll session can report resizes that happen out of sight above the viewport: a post drawn for the first time by `content-visibility` (leaving its placeholder height), or growing as images and embeds load.
      const postHeights = new WeakMap();
      const postResizeObserver = new ResizeObserver(function(entries) {
        const placeholderHeight = parseFloat((getComputedStyle(entries[0].target).containIntrinsicHeight || '').replace('auto', ''));
        entries.forEach(function(entry) {
          const height = entry.borderBoxSize && entry.borderBoxSize[0] ? entry.borderBoxSize[0].blockSize : entry.target.getBoundingClientRect().height;
          const previous = postHeights.get(entry.target);
          postHeights.set(entry.target, height);
          const s = frameSession;
          if (previous === undefined || !s || s.kind !== 'scroll' || Math.abs(height - previous) < 1) { return; }
          const rect = entry.target.getBoundingClientRect();
          if (rect.top >= 0) { return; }
          if (rect.bottom <= 0) { s.shifts.above++; } else { s.shifts.straddling++; }
          if (Math.abs(previous - placeholderHeight) < 1) { s.shifts.firstRender++; } else { s.shifts.growth++; }
          s.shifts.px += Math.round(Math.abs(height - previous));
        });
      });
      function observePosts(root) {
        (root.matches && root.matches('post') ? [root] : Array.from(root.querySelectorAll ? root.querySelectorAll('post') : []))
          .forEach(function(post) { postResizeObserver.observe(post); });
      }
      document.addEventListener('DOMContentLoaded', function() {
        observePosts(document);
        // Endless scroll appends posts later.
        new MutationObserver(function(mutations) {
          mutations.forEach(function(m) { m.addedNodes.forEach(observePosts); });
        }).observe(document.body, { childList: true, subtree: true });
      });

      function hostOf(url) {
        try { return new URL(url).host || url.split(':')[0]; } catch (e) { return '?'; }
      }

      function snapshot() {
        const imgs = Array.from(document.images);
        let complete = 0, broken = 0, lazy = 0, gifs = 0, decodedBytes = 0, largest = null, largestPixels = 0;
        const imageHosts = {};
        imgs.forEach(function(img) {
          if (img.loading === 'lazy') { lazy++; }
          if (/\.gif($|\?)/i.test(img.currentSrc || img.src)) { gifs++; }
          if (img.complete) {
            if (img.naturalWidth === 0) { broken++; return; }
            complete++;
            const pixels = img.naturalWidth * img.naturalHeight;
            decodedBytes += pixels * 4;
            if (pixels > largestPixels) {
              largestPixels = pixels;
              largest = img.naturalWidth + 'x' + img.naturalHeight + ' ' + hostOf(img.currentSrc || img.src);
            }
            const host = hostOf(img.currentSrc || img.src);
            imageHosts[host] = (imageHosts[host] || 0) + 1;
          }
        });
        const iframeHosts = {};
        Array.from(document.querySelectorAll('iframe')).forEach(function(f) {
          const host = hostOf(f.src);
          iframeHosts[host] = (iframeHosts[host] || 0) + 1;
        });
        const posts = Array.from(document.querySelectorAll('post'));
        // Posts that `content-visibility: auto` hasn't rendered yet still sit at their placeholder height. (WebKit ignores checkVisibility's contentVisibilityAuto option, so it can't tell us.)
        const placeholderHeight = posts.length ? parseFloat((getComputedStyle(posts[0]).containIntrinsicHeight || '').replace('auto', '')) : NaN;
        const unrenderedPosts = isNaN(placeholderHeight) ? null
          : posts.filter(function(p) { return Math.abs(p.getBoundingClientRect().height - placeholderHeight) < 1; }).length;
        return {
          domNodes: document.getElementsByTagName('*').length,
          posts: posts.length,
          unrenderedPosts: unrenderedPosts,
          pageDividers: Array.from(document.querySelectorAll('.endless-page-divider')).map(function(d) { return d.textContent.trim(); }),
          docHeight: document.documentElement.scrollHeight,
          images: { total: imgs.length, lazy: lazy, complete: complete, broken: broken, pending: imgs.length - complete - broken, gifs: gifs },
          estDecodedImageMB: Math.round(decodedBytes / 10485.76) / 100,
          largestImage: largest,
          topImageHosts: Object.entries(imageHosts).sort(function(a, b) { return b[1] - a[1]; }).slice(0, 5),
          videos: document.querySelectorAll('video').length,
          iframes: iframeHosts,
          lottiePlayers: document.querySelectorAll('lottie-player').length,
          scripts: document.scripts.length
        };
      }

      function resources() {
        const entries = performance.getEntriesByType('resource');
        const byType = {};
        let transfer = 0, encoded = 0, decoded = 0;
        entries.forEach(function(e) {
          const t = byType[e.initiatorType] || (byType[e.initiatorType] = { count: 0, transferKB: 0 });
          t.count++;
          t.transferKB += Math.round(e.transferSize / 1024);
          transfer += e.transferSize;
          encoded += e.encodedBodySize;
          decoded += e.decodedBodySize;
        });
        const slowest = entries.slice().sort(function(a, b) { return b.duration - a.duration; }).slice(0, 5)
          .map(function(e) { return { host: hostOf(e.name), type: e.initiatorType, ms: Math.round(e.duration), kb: Math.round(e.encodedBodySize / 1024) }; });
        // Cross-origin responses without Timing-Allow-Origin report zero sizes, so these undercount.
        return {
          count: entries.length,
          byType: byType,
          transferMB: Math.round(transfer / 10485.76) / 100,
          encodedMB: Math.round(encoded / 10485.76) / 100,
          decodedMB: Math.round(decoded / 10485.76) / 100,
          slowest: slowest
        };
      }

      function navigation() {
        const nav = performance.getEntriesByType('navigation')[0];
        if (!nav) { return null; }
        return {
          domInteractive: Math.round(nav.domInteractive),
          domContentLoaded: Math.round(nav.domContentLoadedEventEnd),
          loadEvent: Math.round(nav.loadEventEnd)
        };
      }

      // Times a full relayout (as after a font size change or rotation) by nudging the body's width and back.
      function relayoutMs() {
        const body = document.body;
        if (!body) { return null; }
        const width = body.style.width;
        const start = performance.now();
        body.style.width = (document.documentElement.clientWidth - 1) + 'px';
        void body.offsetHeight;
        body.style.width = width;
        void body.offsetHeight;
        return Math.round((performance.now() - start) * 10) / 10;
      }

      // A full relayout blocks the page (and its GIFs and animations) for tens of milliseconds, so after a scroll it's only timed again once the document has changed, as after an endless scroll insert.
      let postsAtLastRelayout = -1;
      function relayoutMsIfChanged(reason) {
        const posts = document.getElementsByTagName('post').length;
        if (reason === 'scroll-end' && posts === postsAtLastRelayout) { return null; }
        postsAtLastRelayout = posts;
        return relayoutMs();
      }

      perf.report = function(reason) {
        post('snapshot', {
          reason: reason,
          relayoutMs: relayoutMsIfChanged(reason),
          features: {
            contentVisibility: CSS.supports('content-visibility', 'auto'),
            scrollAnchoring: CSS.supports('overflow-anchor', 'auto'),
            lazyIframes: 'loading' in HTMLIFrameElement.prototype
          },
          navigation: navigation(),
          lcp: perf.lcp || null,
          longTasks: perf.supported.longtask ? perf.longTasks : 'unsupported',
          slowEvents: perf.slowEvents.splice(0),
          dom: snapshot(),
          resources: resources()
        });
      };

      startFrames('load');

      document.addEventListener('DOMContentLoaded', function() {
        post('domContentLoaded', { domNodes: document.getElementsByTagName('*').length, images: document.images.length });
      });

      window.addEventListener('load', function() {
        perf.report('load');
        setTimeout(function() {
          post('frames', stopFrames());
          perf.report('load+5s');
        }, 5000);
      });

      // Which page's posts are at the top of the viewport: the last endless-scroll divider scrolled past, or 0 for the page first loaded. Reported when it changes, so an automated test can tell how far it has scrolled.
      let lastTopPage = null;
      let lastTopPageCheck = 0;
      function reportTopPage() {
        let page = 0;
        for (const divider of document.querySelectorAll('.endless-page-divider')) {
          if (divider.getBoundingClientRect().top > 0) { break; }
          const match = /Page (\d+)/.exec(divider.textContent);
          if (match) { page = parseInt(match[1], 10); }
        }
        if (page !== lastTopPage) {
          lastTopPage = page;
          post('position', { topPage: page });
        }
      }

      let scrollEndTimer = 0;
      window.addEventListener('scroll', function() {
        // Flush long sessions too, since momentum from repeated flicks can keep one going until the page is replaced.
        if (frameSession && (frameSession.kind !== 'scroll' || performance.now() - frameSession.begin > 5000)) {
          post('frames', stopFrames());
        }
        startFrames('scroll');
        if (performance.now() - lastTopPageCheck > 200) {
          lastTopPageCheck = performance.now();
          reportTopPage();
        }
        clearTimeout(scrollEndTimer);
        scrollEndTimer = setTimeout(function() {
          reportTopPage();
          post('frames', stopFrames());
          perf.report('scroll-end');
        }, 1000);
      }, { passive: true });
    })();
    """#
    #endif
}

#if DEBUG
/**
 Logs how smoothly a scroll view moved during each scroll gesture (the drag plus any deceleration), for the probe. Per gesture it reports:

 - Hitches: display frames the app's main thread delivered late, which stutter the scroll itself.
 - Reversals: frames where the offset moved against the gesture. Usually scroll anchoring correcting for content that changed height above the viewport; visible as jitter if the correction lands a frame after the content moved.
 - Leaps: single frames that moved much further than the frames either side of them (a fling speeding up or slowing down doesn't count). Each is classified by where in the gesture it happened, since synthetic touches (as in UI tests) can start and end abruptly: `touchDown` (the first few frames of a drag), `release` (around the finger lifting), `dragging`, `decelerating`, or `resize` (the content size changed that frame, whatever the gesture was doing).
 - Content size changes while scrolling.

 Add it to the scroll view's `ScrollViewDelegateMultiplexer`, and keep a strong reference to it (the multiplexer's is weak).
 */
final class ScrollJankMonitor: NSObject, ScrollViewDelegateExtras {
    private let label: () -> String
    private var displayLink: CADisplayLink?
    private weak var scrollView: UIScrollView?
    private var session: Session?

    private struct Session {
        let begin: CFTimeInterval
        let startOffset: CGFloat
        var frames = 0
        var hitches = 0
        var hitchTime: CFTimeInterval = 0
        var worstHitch: CFTimeInterval = 0
        var previousTargetTimestamp: CFTimeInterval = 0
        var previousOffset: CGFloat
        /// +1 scrolling down the page, -1 up, 0 until the gesture has moved far enough to tell.
        var direction: CGFloat = 0
        var reversals = 0
        var reversalDistance: CGFloat = 0
        var largestReversal: CGFloat = 0
        var leaps = 0
        var largestLeap: CGFloat = 0
        /// Leap counts and largest leap by where in the gesture they happened; see `leapContext(of:)`.
        var leapsAt: [String: Int] = [:]
        var largestLeapAt: [String: CGFloat] = [:]
        /// The previous two frames' movement, to spot a single-frame spike once the frame after it arrives.
        var previousDelta: CGFloat = 0
        var deltaBeforePrevious: CGFloat = 0
        /// The previous frame's context, since a spike is only recognized a frame later.
        var previousContext = FrameContext()
        var dragBeganFrame = 0
        var dragEndedFrame: Int?
        var contentSizeChangedThisFrame = false
        var contentSizeChanges = 0

        /// Where in the gesture a frame was. The content resizing and the finger touching down or lifting are checked first, since a leap then is most likely caused by that (synthetic touches start and stop abruptly).
        func leapContext(of frame: FrameContext) -> String {
            if frame.contentSizeChanged { return "resize" }
            if frame.dragging, frame.index - dragBeganFrame <= 3 { return "touchDown" }
            if let dragEndedFrame, abs(frame.index - dragEndedFrame) <= 2 { return "release" }
            return frame.dragging ? "dragging" : "decelerating"
        }
    }

    private struct FrameContext {
        var index = 0
        var dragging = false
        var contentSizeChanged = false
    }

    /// - Parameter label: Names the page in log lines, to match the probe's other output.
    init(label: @escaping () -> String) {
        self.label = label
    }

    deinit {
        displayLink?.invalidate()
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        // A drag that interrupts deceleration continues the same session.
        if var s = session {
            s.dragBeganFrame = s.frames
            s.dragEndedFrame = nil
            session = s
            return
        }
        self.scrollView = scrollView
        let offset = scrollView.contentOffset.y
        session = Session(begin: CACurrentMediaTime(), startOffset: offset, previousOffset: offset)
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if let frames = session?.frames { session?.dragEndedFrame = frames }
        if !decelerate { finish() }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        finish()
    }

    func scrollViewDidChangeContentSize(_ scrollView: UIScrollView) {
        guard session != nil else { return }
        session?.contentSizeChanges += 1
        session?.contentSizeChangedThisFrame = true
    }

    @objc private func tick(_ link: CADisplayLink) {
        guard var s = session, let scrollView else { return }
        let frameDuration = link.targetTimestamp - link.timestamp
        if s.previousTargetTimestamp > 0 {
            s.frames += 1
            // Late by more than half a frame counts as a hitch (as in Instruments' hitch detection).
            let lateness = link.timestamp - s.previousTargetTimestamp
            if lateness > frameDuration / 2 {
                s.hitches += 1
                s.hitchTime += lateness
                s.worstHitch = max(s.worstHitch, lateness)
            }
        }
        s.previousTargetTimestamp = link.targetTimestamp

        let context = FrameContext(index: s.frames, dragging: scrollView.isDragging, contentSizeChanged: s.contentSizeChangedThisFrame)
        s.contentSizeChangedThisFrame = false
        let offset = scrollView.contentOffset.y
        let delta = offset - s.previousOffset
        s.previousOffset = offset
        if s.direction == 0, abs(offset - s.startOffset) > 4 {
            s.direction = offset > s.startOffset ? 1 : -1
        }
        // Rubber-banding past either end reverses the offset by design, so skip it.
        let minOffset = -scrollView.adjustedContentInset.top
        let maxOffset = max(minOffset, scrollView.contentSize.height + scrollView.adjustedContentInset.bottom - scrollView.bounds.height)
        if offset >= minOffset, offset <= maxOffset {
            if s.direction != 0, delta * s.direction < -0.5 {
                s.reversals += 1
                s.reversalDistance += abs(delta)
                s.largestReversal = max(s.largestReversal, abs(delta))
            }
            let spike = abs(s.previousDelta)
            if spike > 12, spike > abs(s.deltaBeforePrevious) * 3, spike > abs(delta) * 3 {
                s.leaps += 1
                s.largestLeap = max(s.largestLeap, spike)
                let at = s.leapContext(of: s.previousContext)
                s.leapsAt[at, default: 0] += 1
                s.largestLeapAt[at] = max(s.largestLeapAt[at] ?? 0, spike)
            }
        }
        s.deltaBeforePrevious = s.previousDelta
        s.previousDelta = delta
        s.previousContext = context
        session = s
    }

    private func finish() {
        displayLink?.invalidate()
        displayLink = nil
        guard let s = session else { return }
        session = nil
        let duration = CACurrentMediaTime() - s.begin
        let height = scrollView?.contentSize.height ?? 0
        let report: [String: Any] = [
            "durationMs": Int(duration * 1000),
            "distance": Int((scrollView?.contentOffset.y ?? s.startOffset) - s.startOffset),
            "frames": s.frames,
            "hitches": s.hitches,
            "hitchTimeMs": Int(s.hitchTime * 1000),
            // Apple's hitch ratio: under 5 ms/s is good, over 10 ms/s is noticeable.
            "hitchRatioMsPerS": duration > 0 ? (s.hitchTime * 1000 / duration * 10).rounded() / 10 : 0,
            "worstHitchMs": Int(s.worstHitch * 1000),
            "reversals": s.reversals,
            "reversalPx": Int(s.reversalDistance),
            "largestReversalPx": Int(s.largestReversal),
            "leaps": s.leaps,
            "largestLeapPx": Int(s.largestLeap),
            "leapsAt": s.leapsAt,
            "largestLeapPxAt": s.largestLeapAt.mapValues { Int($0) },
            "contentSizeChanges": s.contentSizeChanges,
            "contentHeight": Int(height),
        ]
        let json = (try? JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "\(report)"
        PostsPerformance.logger.info("[\(self.label(), privacy: .public)] native scroll \(json, privacy: .public)")
    }
}
#endif
