//  TrackingParameterRemover.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

/// Removes known tracking query parameters (`utm_*`, `fbclid`, per-site share tokens like YouTube's `si`) from URLs, leaving functional parameters (YouTube timestamps, Reddit comment context, etc.) intact.
///
/// The rule set follows the consensus of the ClearURLs, Brave, uBlock Origin, and AdGuard tracking-parameter databases.
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
                let keep = matchingRules.contains { $0.keepExact.contains(name) }
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
    /// Query-item names to remove, compared against the percent-decoded, lowercased name.
    var removeExact: Set<String> = []
    var removePrefixes: [String] = []
    /// Names that must survive on this rule's hosts even if another rule would remove them.
    var keepExact: Set<String> = []
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
        removeExact.contains(decodedLowercasedName)
            || removePrefixes.contains { decodedLowercasedName.hasPrefix($0) }
    }
}

private let rules: [TrackingRule] = [
    // Cross-site trackers, safe to strip on any domain.
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
    // YouTube (music.youtube.com etc. match via suffix)
    TrackingRule(
        hostSuffixes: ["youtube.com", "youtu.be", "youtube-nocookie.com"],
        removeExact: [
            "si", "is", "feature", "pp", "kw",
            "embeds_referring_euri", "embeds_referring_origin", "source_ve_path", "ab_channel",
        ],
        keepExact: ["v", "t", "list", "index", "start", "end", "loop", "playlist", "time_continue", "q"]
    ),
    // Twitter/X
    TrackingRule(
        hostSuffixes: ["twitter.com", "x.com"],
        removeExact: ["s", "t", "ref_src", "refsrc", "ref_url", "cxt", "cn"],
        keepExact: ["q", "f", "lang"]
    ),
    // Instagram/Threads
    TrackingRule(
        hostSuffixes: ["instagram.com", "threads.net", "threads.com"],
        removeExact: ["igsh", "igshid", "ig_rid", "xmt"],
        keepExact: ["img_index", "hl"]
    ),
    // TikTok (vm./vt.tiktok.com short links carry no query params and pass through)
    TrackingRule(
        hostSuffixes: ["tiktok.com"],
        removeExact: [
            "is_from_webapp", "sender_device", "sender_web_id", "web_id",
            "u_code", "share_app_id", "share_app_name", "share_author_id",
            "share_link_id", "share_item_id", "share_iid", "share_region",
            "social_share_type", "ug_btm", "tt_from", "timestamp",
            "user_id", "sec_user_id", "sec_uid",
            "_d", "_r", "_t", "checksum", "k", "preview_pb", "trackparams",
            "refer", "referer_url", "referer_video_id",
            "embed_source", "enter_method", "source",
        ],
        keepExact: ["lang", "enter_from"]
    ),
    // Bluesky
    TrackingRule(
        hostSuffixes: ["bsky.app"],
        removeExact: ["ref_src", "ref_url"]
    ),
    // Reddit ($-names stored decoded; they appear in URLs as %24…)
    TrackingRule(
        hostSuffixes: ["reddit.com"],
        removeExact: [
            "share_id", "rdt", "correlation_id",
            "ref", "ref_campaign", "ref_source",
            "$deep_link", "$3p", "$original_url",
            "_branch_match_id", "entry_point", "post_index", "post_fullname",
        ],
        keepExact: ["context", "sort", "depth", "limit", "q"]
    ),
    // Spotify
    TrackingRule(
        hostSuffixes: ["open.spotify.com"],
        removeExact: ["si", "sp_cid", "dlsi", "pi", "referral", "nd"],
        keepExact: ["context", "highlight"]
    ),
    // Amazon, all marketplace TLDs (amazon.com, amazon.co.uk, amazon.com.au, …)
    TrackingRule(
        hostPredicate: { host in
            host.range(of: #"(^|\.)amazon(\.[a-z]{2,3}){1,2}$"#, options: .regularExpression) != nil
        },
        removeExact: [
            "qid", "sr", "sprefix", "crid", "keywords", "dib", "dib_tag",
            "refrid", "_encoding", "tag", "linkcode", "linkid", "ascsubtag",
        ],
        removePrefixes: ["ref_", "pf_rd_", "pd_rd_"],
        keepExact: ["k", "i", "node", "psc", "th", "s"],
        transformPath: { path in
            guard let range = path.range(of: "/ref=", options: .backwards) else { return path }
            return String(path[..<range.lowerBound])
        }
    ),
]
