//  TextSizeAnnotations.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulSettings
import Combine
import WebKit

// TEXT-SIZE-ANNOTATIONS: a tool for testing builds only, to be removed before a release candidate. To remove it, delete this file and every line tagged TEXT-SIZE-ANNOTATIONS (search the repo for the tag, including Awful.xcodeproj).

/// Labels usernames, reg dates, post text, quote titles, quote text and post dates in a `RenderView` with the font size each is actually drawn at, so a tester can show exactly what their device renders. Turned on by Annotate Text Sizes in the Testing section of Settings, which only testing builds show (see `Environment.isTestingBuild`).
@MainActor
final class TextSizeAnnotations {
    @FoilDefaultStorage(Settings.annotateTextSizes) private var isEnabled
    private var cancellable: AnyCancellable?
    private weak var webView: WKWebView?

    /// Adds the annotation script to `configuration`, or returns `nil` outside testing builds.
    init?(configuration: WKWebViewConfiguration) {
        guard Environment.isTestingBuild else { return nil }
        configuration.userContentController.addUserScript(WKUserScript(source: Self.script, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
    }

    /// Follows the setting in `webView`, which must use the configuration passed to `init`.
    func attach(to webView: WKWebView) {
        self.webView = webView
        cancellable = $isEnabled
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.send($0) }
    }

    /// Call when a document finishes loading, as each new document starts without labels.
    func documentDidLoad() {
        send(isEnabled)
    }

    private func send(_ enabled: Bool) {
        guard let webView else { return }
        Task {
            _ = try? await webView.eval("if (window.Awful && Awful.setTextSizeAnnotations) Awful.setTextSizeAnnotations(\(enabled ? "true" : "false"))")
        }
    }

    /// Sizes are in points, as a CSS pixel is a point. A label goes on the element it describes, except quote text's, which goes on its quote so a collapsed quote can't clip it.
    private static let script = #"""
    (function() {
      if (!window.Awful) { window.Awful = {}; }

      var ATTRIBUTE = 'data-awful-text-size';
      var STYLE_ID = 'awful-text-size-annotations';
      var KINDS = '.postbody, .bbc-block > h4, .bbc-block > blockquote';
      var CSS = `
        .postbody { --awful-text-size-color: #ffcc00; }
        .bbc-block > h4 { --awful-text-size-color: #4cd964; }
        .bbc-block > blockquote, .bbc-block { --awful-text-size-color: #5ac8fa; }
        .nameanddate { --awful-text-size-color: #ff9f0a; }
        .postdate { --awful-text-size-color: #bf5af2; }
        .postbody, .bbc-block > h4, .bbc-block > blockquote, .username, .regdate, .postdate {
          outline: 1px dashed var(--awful-text-size-color);
          outline-offset: 1px;
        }
        [data-awful-text-size]::after {
          content: attr(data-awful-text-size);
          padding: 1px 5px;
          border-radius: 4px;
          font: 600 10px/1.3 ui-monospace, Menlo, monospace;
          font-style: normal;
          letter-spacing: 0;
          text-transform: none;
          white-space: normal;
          overflow-wrap: anywhere;
          max-width: 100%;
          color: #000;
          -webkit-text-fill-color: #000;
          background-color: var(--awful-text-size-color);
          pointer-events: none;
        }
        .postbody[data-awful-text-size]::after,
        .bbc-block[data-awful-text-size]::after,
        .nameanddate[data-awful-text-size]::after {
          display: table;
          margin-top: 4px;
        }
        .bbc-block > h4[data-awful-text-size]::after {
          display: inline-block;
          margin-left: 6px;
          vertical-align: middle;
        }
        .postdate[data-awful-text-size] {
          position: relative;
        }
        .postdate[data-awful-text-size]::after {
          position: absolute;
          top: 100%;
          right: 0;
          z-index: 1;
          margin-top: 2px;
          max-width: none;
          white-space: nowrap;
        }
      `;

      var observer = null;
      var isRefreshPending = false;

      function points(cssLength) {
        return parseFloat(cssLength).toFixed(1) + 'pt';
      }

      function fontSize(element) {
        return points(getComputedStyle(element).fontSize);
      }

      function describeElement(element) {
        var name = element.tagName.toLowerCase();
        return element.classList.length ? name + '.' + element.classList[0] : name;
      }

      // Splits a selector list at its top-level commas, leaving those inside :not() and the like alone.
      function splitSelectors(selectorText) {
        var selectors = [];
        var depth = 0;
        var start = 0;
        for (var i = 0; i < selectorText.length; i += 1) {
          var character = selectorText[i];
          if (character === '(') { depth += 1; }
          else if (character === ')') { depth -= 1; }
          else if (character === ',' && depth === 0) {
            selectors.push(selectorText.slice(start, i).trim());
            start = i + 1;
          }
        }
        selectors.push(selectorText.slice(start).trim());
        return selectors;
      }

      // Close enough to CSS specificity for the selectors in our stylesheets: :where() counts for nothing and :not(), :is() and :has() count as their argument.
      function specificity(selector) {
        var s = selector
          .replace(/::[\w-]+(\([^)]*\))?/g, '')
          .replace(/:where\([^)]*\)/g, '')
          .replace(/:(not|is|has)\(([^)]*)\)/g, ' $2 ');
        var ids = (s.match(/#[\w-]+/g) || []).length;
        var classes = (s.match(/\.[\w-]+|\[[^\]]*\]|:[\w-]+/g) || []).length;
        var types = (s.match(/(^|[\s>+~(])[a-zA-Z][\w-]*/g) || []).length;
        return ids * 10000 + classes * 100 + types;
      }

      // Every style rule (including those in media queries that apply) declaring `property`, in document order.
      function collectRules(property) {
        var rules = [];
        var order = 0;
        function collect(list) {
          Array.prototype.forEach.call(list, function(rule) {
            if (rule.selectorText !== undefined && rule.style) {
              order += 1;
              var value = rule.style.getPropertyValue(property);
              var priority = rule.style.getPropertyPriority(property);
              if (!value) {
                // A system font such as `font: -apple-system-footnote` sets font-size to its own keyword, which getPropertyValue leaves out but cssText includes.
                var match = new RegExp('(?:^|;)\\s*' + property + ':\\s*([^;]+)').exec(rule.style.cssText);
                if (match) {
                  value = match[1].replace(/\s*!important\s*$/, '').trim();
                  priority = /!important\s*$/.test(match[1]) ? 'important' : '';
                }
              }
              if (!value) { return; }
              var ruleOrder = order;
              splitSelectors(rule.selectorText).forEach(function(selector) {
                rules.push({ selector: selector, value: value, important: priority === 'important', specificity: specificity(selector), order: ruleOrder });
              });
            } else if (rule.cssRules) {
              if (rule.media && rule.media.mediaText && !window.matchMedia(rule.media.mediaText).matches) { return; }
              collect(rule.cssRules);
            }
          });
        }
        Array.prototype.forEach.call(document.styleSheets, function(sheet) {
          if (sheet.ownerNode && sheet.ownerNode.id === STYLE_ID) { return; }
          try { collect(sheet.cssRules); } catch (error) {}
        });
        return rules;
      }

      function outranks(rule, other) {
        if (rule.important !== other.important) { return rule.important; }
        if (rule.specificity !== other.specificity) { return rule.specificity > other.specificity; }
        return rule.order > other.order;
      }

      // The value the cascade gives `element` for one of the properties in `cascade`, with any custom properties it uses resolved, or "inherited" when no rule sets it.
      function declaredValue(element, property) {
        var winner = null;
        cascade[property].forEach(function(rule) {
          var matches = false;
          try { matches = element.matches(rule.selector); } catch (error) {}
          if (matches && (!winner || outranks(rule, winner))) { winner = rule; }
        });
        var inline = element.style && element.style.getPropertyValue(property);
        var value = inline && !(winner && winner.important) ? inline : (winner ? winner.value : 'inherited');
        var computed = getComputedStyle(element);
        return value.replace(/var\((--[\w-]+)[^)]*\)/g, function(match, name) {
          return match + '=' + (computed.getPropertyValue(name).trim() || 'unset');
        });
      }

      // Rules declaring the properties labels explain, collected afresh on each refresh as the theme and font scale stylesheets come and go.
      var cascade = {};

      // The element's size and the CSS value that gave it.
      function sizeAndSource(element) {
        return fontSize(element) + ' ← ' + declaredValue(element, 'font-size');
      }

      // The element's own size, plus any different sizes its own text is drawn at (text in a nested post, title or quote text is left to that one's label).
      function describeSizes(element) {
        var size = fontSize(element);
        var seen = {};
        seen[size] = true;
        var others = [];
        var walker = document.createTreeWalker(element, NodeFilter.SHOW_TEXT);
        for (var checked = 0; walker.nextNode() && checked < 300 && others.length < 2; checked += 1) {
          var parent = walker.currentNode.parentElement;
          if (!walker.currentNode.data.trim() || !parent || parent.closest(KINDS) !== element) { continue; }
          var otherSize = fontSize(parent);
          if (seen[otherSize]) { continue; }
          seen[otherSize] = true;
          others.push(otherSize + ' in ' + describeElement(parent));
        }
        var described = size + ' ← ' + declaredValue(element, 'font-size');
        return others.length ? described + ' (also ' + others.join(', ') + ')' : described;
      }

      function setLabel(element, label) {
        if (element.getAttribute(ATTRIBUTE) !== label) {
          element.setAttribute(ATTRIBUTE, label);
        }
      }

      function refresh() {
        isRefreshPending = false;
        cascade = { 'font-size': collectRules('font-size'), 'width': collectRules('width') };
        document.querySelectorAll('.postbody').forEach(function(postbody) {
          setLabel(postbody, 'post ' + describeSizes(postbody));
        });
        document.querySelectorAll('.bbc-block > h4').forEach(function(title) {
          var label = 'title ' + describeSizes(title);
          var arrow = title.querySelector('.quote-collapse-toggle img');
          if (arrow) {
            label += ' · arrow ' + points(getComputedStyle(arrow).width) + ' ← ' + declaredValue(arrow, 'width');
          }
          setLabel(title, label);
        });
        document.querySelectorAll('.bbc-block > blockquote').forEach(function(text) {
          setLabel(text.parentElement, 'quote text ' + describeSizes(text) + ' · box ' + sizeAndSource(text.parentElement));
        });
        // The username's own pseudo-elements are taken by role and platinum icons, so its label goes on the section it shares with the reg date.
        document.querySelectorAll('.nameanddate').forEach(function(nameAndDate) {
          var parts = [];
          var username = nameAndDate.querySelector('.username');
          if (username) { parts.push('name ' + sizeAndSource(username)); }
          var regdate = nameAndDate.querySelector('.regdate');
          if (regdate) { parts.push('reg date ' + sizeAndSource(regdate)); }
          if (parts.length) { setLabel(nameAndDate, parts.join(' · ')); }
        });
        document.querySelectorAll('footer .postdate').forEach(function(postdate) {
          setLabel(postdate, 'post date ' + sizeAndSource(postdate));
        });
      }

      // Posts, quote arrows and stylesheets (the theme's and the font scale's) all arrive as added or replaced nodes. Labels are attributes, so setting them doesn't trigger another refresh.
      function scheduleRefresh() {
        if (isRefreshPending) { return; }
        isRefreshPending = true;
        requestAnimationFrame(refresh);
      }

      Awful.setTextSizeAnnotations = function(enabled) {
        var style = document.getElementById(STYLE_ID);
        if (enabled) {
          if (!style) {
            style = document.createElement('style');
            style.id = STYLE_ID;
            style.textContent = CSS;
            document.head.appendChild(style);
          }
          if (!observer) {
            observer = new MutationObserver(scheduleRefresh);
            observer.observe(document.documentElement, { childList: true, subtree: true });
          }
          scheduleRefresh();
        } else {
          if (observer) {
            observer.disconnect();
            observer = null;
          }
          if (style) {
            style.remove();
          }
          document.querySelectorAll('[' + ATTRIBUTE + ']').forEach(function(element) {
            element.removeAttribute(ATTRIBUTE);
          });
        }
      };
    })();
    """#
}
