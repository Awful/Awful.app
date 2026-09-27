//  RenderViewPerformance.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import os
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

    /// Injected at document start so it observes the whole load, including first paint.
    static let probeScript = WKUserScript(source: probeSource, injectionTime: .atDocumentStart, forMainFrameOnly: true)

    private static let probeSource = #"""
    (function() {
      if (window.AwfulPerf) { return; }

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
        if (s.last) {
          const gap = timestamp - s.last;
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
        frameSession = { kind: kind, begin: performance.now(), startY: window.scrollY, frames: 0, dropped: 0, longFrames: 0, maxGap: 0, last: 0 };
        frameRequest = requestAnimationFrame(tick);
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
          maxFrameGapMs: Math.round(s.maxGap)
        };
      }

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
        return {
          domNodes: document.getElementsByTagName('*').length,
          posts: document.querySelectorAll('post').length,
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

      perf.report = function(reason) {
        post('snapshot', {
          reason: reason,
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

      let scrollEndTimer = 0;
      window.addEventListener('scroll', function() {
        // Flush long sessions too, since momentum from repeated flicks can keep one going until the page is replaced.
        if (frameSession && (frameSession.kind !== 'scroll' || performance.now() - frameSession.begin > 5000)) {
          post('frames', stopFrames());
        }
        startFrames('scroll');
        clearTimeout(scrollEndTimer);
        scrollEndTimer = setTimeout(function() {
          post('frames', stopFrames());
          perf.report('scroll-end');
        }, 1000);
      }, { passive: true });
    })();
    """#
    #endif
}
