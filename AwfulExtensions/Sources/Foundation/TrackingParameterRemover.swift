//  TrackingParameterRemover.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

/// Removes tracking query parameters from URLs, leaving functional parameters (YouTube timestamps, Reddit comment context, etc.) intact.
///
/// On known sites (YouTube, X, Reddit, Amazon, …) each rule is a keep-list: every query parameter that isn't known to be functional is removed, so new share tokens are caught without rule updates. Everywhere else a blocklist of cross-site trackers (`utm_*`, `fbclid`, …) applies, following the consensus of the ClearURLs, Brave, uBlock Origin, and AdGuard tracking-parameter databases.
public enum TrackingParameterRemover {

    /// Returns a cleaned copy of `url`, or `nil` if nothing needed removing. Only http(s) URLs with a host are ever modified.
    public static func cleanedURL(_ url: URL) -> URL? {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              var components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let host = components.host?.lowercased(),
              !host.isEmpty
        else { return nil }

        let matchingRules = rules.filter { $0.matches(host: host) }
        guard !matchingRules.isEmpty else { return nil }

        for rule in matchingRules {
            if let transformPath = rule.transformPath {
                components.percentEncodedPath = transformPath(components.percentEncodedPath)
            }
        }

        if let items = components.percentEncodedQueryItems, !items.isEmpty {
            let kept = items.filter { item in
                let name = (item.name.removingPercentEncoding ?? item.name).lowercased()
                let keep = matchingRules.contains { $0.keepOnly?.contains(name) == true }
                let remove = matchingRules.contains { $0.removes(name) }
                return keep || !remove
            }
            if kept.isEmpty {
                components.query = nil
            } else if kept.count != items.count {
                components.percentEncodedQueryItems = kept
            }
        }

        guard let cleaned = components.url, cleaned.absoluteString != url.absoluteString else { return nil }
        return cleaned
    }

    /// Finds http(s) URLs inside arbitrary text and cleans each one.
    public static func cleanedText(_ text: String) -> TextCleaningResult {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return TextCleaningResult(cleanedText: text, replacements: [])
        }
        let nsText = text as NSString
        let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))

        // (range in original text, original substring, cleaned substring)
        var changes: [(NSRange, String, String)] = []
        for match in matches {
            // Use the matched substring, not match.url: NSDataDetector normalizes URLs (adds schemes, tweaks encoding) and we must never insert text the user didn't paste. Skipping scheme-less matches (www.foo.com) for the same reason.
            let substring = nsText.substring(with: match.range)
            let lowercased = substring.lowercased()
            guard lowercased.hasPrefix("http://") || lowercased.hasPrefix("https://"),
                  let url = URL(string: substring),
                  let cleaned = cleanedURL(url)
            else { continue }
            changes.append((match.range, substring, cleaned.absoluteString))
        }

        guard !changes.isEmpty else {
            return TextCleaningResult(cleanedText: text, replacements: [])
        }

        let result = NSMutableString(string: text)
        for (range, _, cleaned) in changes.reversed() {
            result.replaceCharacters(in: range, with: cleaned)
        }

        var replacements: [Replacement] = []
        var delta = 0
        for (range, original, cleaned) in changes {
            let location = range.location + delta
            let cleanedLength = (cleaned as NSString).length
            replacements.append(Replacement(
                original: original,
                cleaned: cleaned,
                range: NSRange(location: location, length: cleanedLength)
            ))
            delta += cleanedLength - range.length
        }

        return TextCleaningResult(cleanedText: result as String, replacements: replacements)
    }

    public struct TextCleaningResult {
        /// The full text with every cleanable URL replaced by its cleaned form.
        public let cleanedText: String

        /// One entry per URL that actually changed.
        public let replacements: [Replacement]

        public var didChange: Bool { !replacements.isEmpty }
    }

    public struct Replacement: Equatable {
        /// The URL exactly as it appeared in the input text.
        public let original: String

        /// The cleaned absolute URL string that now appears in `cleanedText`.
        public let cleaned: String

        /// UTF-16 range of `cleaned` within `cleanedText`.
        public let range: NSRange
    }
}

private struct TrackingRule {
    /// Lowercased registrable-domain suffixes; a host matches when it equals a suffix or ends with "." + suffix. Empty (with no predicate) means the rule applies to every host.
    var hostSuffixes: [String] = []
    var hostPredicate: ((String) -> Bool)?
    /// Query-item names to remove, compared against the percent-decoded, lowercased name. Only used when `keepOnly` is nil.
    var removeExact: Set<String> = []
    var removePrefixes: [String] = []
    /// When set, this rule is a keep-list: every query item whose (decoded, lowercased) name isn't in it is removed, and names in it survive even if another rule would remove them.
    var keepOnly: Set<String>?
    /// Transform applied to the URL's percent-encoded path (e.g. Amazon's "/ref=…" suffix).
    var transformPath: ((String) -> String)?

    func matches(host: String) -> Bool {
        if let hostPredicate {
            return hostPredicate(host)
        }
        if hostSuffixes.isEmpty {
            return true
        }
        return hostSuffixes.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    func removes(_ decodedLowercasedName: String) -> Bool {
        if let keepOnly {
            return !keepOnly.contains(decodedLowercasedName)
        }
        return removeExact.contains(decodedLowercasedName)
            || removePrefixes.contains { decodedLowercasedName.hasPrefix($0) }
    }
}

private let rules: [TrackingRule] = [
    // Cross-site trackers, safe to strip on any domain. This is the only blocklist; every site rule below is a keep-list.
    TrackingRule(
        removeExact: [
            "fbclid", "gclid", "gclsrc", "dclid", "wbraid", "gbraid",
            "msclkid", "twclid", "ttclid", "yclid",
            "mc_cid", "mc_eid",
            "_hsenc", "__hstc", "__hssc", "__hsfp", "_hsmi",
            "_ga", "_gl", "srsltid", "igshid",
        ],
        removePrefixes: ["utm_"]
    ),
    // YouTube (music.youtube.com etc. match via suffix). lc = linked comment, search_query/sp = search and its filters, the rest are embed player options.
    TrackingRule(
        hostSuffixes: ["youtube.com", "youtu.be", "youtube-nocookie.com"],
        keepOnly: [
            "v", "t", "list", "index", "start", "end", "loop", "playlist", "time_continue",
            "q", "search_query", "sp", "lc", "hl", "gl",
            "autoplay", "mute", "controls", "rel", "cc_load_policy", "cc_lang_pref", "playsinline",
        ]
    ),
    // Twitter/X: only search uses query params (f = tab, pf = "people you follow" filter); share links keep sprouting new tokens (s, t, a, …).
    TrackingRule(
        hostSuffixes: ["twitter.com", "x.com"],
        keepOnly: ["q", "f", "pf", "lang"]
    ),
    // Instagram/Threads
    TrackingRule(
        hostSuffixes: ["instagram.com", "threads.net", "threads.com"],
        keepOnly: ["img_index", "hl"]
    ),
    // TikTok (vm./vt.tiktok.com short links carry no query params and pass through)
    TrackingRule(
        hostSuffixes: ["tiktok.com"],
        keepOnly: ["lang", "enter_from", "q"]
    ),
    // Bluesky
    TrackingRule(
        hostSuffixes: ["bsky.app"],
        keepOnly: ["q"]
    ),
    // Reddit: t = "top" time range, after/before/count = listing pagination, restrict_sr/type/include_over_18/f = search options.
    TrackingRule(
        hostSuffixes: ["reddit.com"],
        keepOnly: [
            "context", "sort", "depth", "limit", "q", "t", "type", "restrict_sr",
            "include_over_18", "after", "before", "count", "f",
        ]
    ),
    // Spotify: t = podcast episode timestamp
    TrackingRule(
        hostSuffixes: ["open.spotify.com"],
        keepOnly: ["context", "highlight", "t"]
    ),
    // Amazon, all marketplace TLDs (amazon.com, amazon.co.uk, amazon.com.au, …). Keeps search/browse refinements (k, i, rh, bbn, s, …), seller selection (smid, m, me), variants (th, psc), wish lists (colid, coliid, ty), and review filters.
    TrackingRule(
        hostPredicate: { host in
            host.range(of: #"(^|\.)amazon(\.[a-z]{2,3}){1,2}$"#, options: .regularExpression) != nil
        },
        keepOnly: [
            "k", "i", "node", "psc", "th", "s", "rh", "bbn", "field-keywords", "page",
            "low-price", "high-price", "smid", "m", "me", "asin", "colid", "coliid", "ty",
            "filter", "sortby", "pagenumber", "filterbystar", "reviewertype", "language",
        ],
        transformPath: { path in
            guard let range = path.range(of: "/ref=", options: .backwards) else { return path }
            return String(path[..<range.lowerBound])
        }
    ),
]
