//  PlatinumIcons.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreGraphics
import Foundation
import ImageIO

/// A custom icon that a platinum user has chosen to show next to their username instead of the usual platinum grenade.
///
/// The Forums mark the author with an extra class (e.g. `<dt class="author platinum feather">`) and map that class to an image in `platicons.css`. We already keep that class in `User.authorClasses`, so all that's needed to show the icon is the class-to-image mapping.
public struct PlatinumIcon: Equatable, Sendable {
    public let className: String
    public let imageURL: URL

    public init(className: String, imageURL: URL) {
        self.className = className
        self.imageURL = imageURL
    }
}

public enum PlatinumIcons {

    /// The Forums stylesheet that maps author classes to icon images. It gets updated in place as new icons are added.
    public static let siteStylesheetURL = URL(string: "https://i.somethingawful.com/css/platicons.css")!

    /// Finds every `dt.<class> { background-image: url(…) }` rule in the Forums' `platicons.css`.
    ///
    /// Only class names that are safe to put in a selector, and only images hosted by the Forums, make it through. Classes that are either styled some other way in the posts view or that the posts view uses for its own purposes are skipped.
    public static func parse(siteStylesheet css: String) -> [PlatinumIcon] {
        let css = commentRegex.stringByReplacingMatches(in: css, range: NSRange(css.startIndex..., in: css), withTemplate: "")

        var icons: [PlatinumIcon] = []
        for rule in ruleRegex.matches(in: css, range: NSRange(css.startIndex..., in: css)) {
            guard let selectors = Range(rule.range(at: 1), in: css).map({ css[$0] }),
                  let body = Range(rule.range(at: 2), in: css).map({ String(css[$0]) }),
                  let urlMatch = backgroundURLRegex.firstMatch(in: body, range: NSRange(body.startIndex..., in: body)),
                  let rawURL = Range(urlMatch.range(at: 1), in: body).map({ String(body[$0]) }),
                  let imageURL = sanitizedImageURL(rawURL)
            else { continue }

            for selector in selectors.split(separator: ",") {
                let selector = String(selector)
                guard let classMatch = selectorClassRegex.firstMatch(in: selector, range: NSRange(selector.startIndex..., in: selector)),
                      let className = Range(classMatch.range(at: 1), in: selector).map({ String(selector[$0]) }),
                      !isReserved(className)
                else { continue }

                // Later rules win, same as in CSS.
                icons.removeAll { $0.className == className }
                icons.append(PlatinumIcon(className: className, imageURL: imageURL))
            }
        }
        return icons
    }

    /// Makes a posts view stylesheet that shows each icon after the author's username, in place of the platinum grenade.
    ///
    /// Icons are drawn as-is, except that black icons (per `isBlack`) take on whatever filter the theme sets in `--awful-black-icon-filter`. Themes use that to give black icons the same treatment as the (black) platinum grenade, e.g. turning them white on dark backgrounds. Icons in any other colour are left alone, as that's a colour the user picked.
    public static func postsViewStylesheet(
        for icons: [PlatinumIcon],
        isBlack: (URL) -> Bool
    ) -> String {
        guard !icons.isEmpty else { return "" }

        func selector(_ icon: PlatinumIcon) -> String {
            "post.\(icon.className) .username:after"
        }

        var css = "/* Generated from \(siteStylesheetURL.absoluteString) */\n"
        css += icons.map(selector).joined(separator: ",\n")
        css += """
             {
              content: "";
              display: inline-block;
              width: 16px;
              height: 16px;
              margin-left: 2px;
              vertical-align: -2px;
              background-size: contain;
              background-repeat: no-repeat;
              background-position: center;
              -webkit-filter: none;
              filter: none;
            }

            """
        for icon in icons {
            css += "\(selector(icon)) { background-image: url(\"\(icon.imageURL.absoluteString)\");"
            if isBlack(icon.imageURL) {
                css += " -webkit-filter: var(--awful-black-icon-filter, none); filter: var(--awful-black-icon-filter, none);"
            }
            css += " }\n"
        }
        return css
    }

    /// Whether an icon is drawn entirely in black (or very dark grey), like the platinum grenade.
    ///
    /// SVGs, which are most of the icons, are checked by reading the colours they use. Anything that could bring in other colours (embedded images, gradients, patterns, filters) counts as not black. Other images are checked pixel by pixel. When in doubt, the answer is `false`, which just means the icon gets shown as-is.
    public static func isBlack(imageData data: Data) -> Bool {
        if let svg = String(data: data, encoding: .utf8), svg.prefix(4096).range(of: "<svg", options: .caseInsensitive) != nil {
            return isBlack(svg: svg)
        } else {
            return isBlack(raster: data)
        }
    }

    private static func isBlack(svg: String) -> Bool {
        let range = NSRange(svg.startIndex..., in: svg)
        guard svgOtherColorSourceRegex.firstMatch(in: svg, range: range) == nil else { return false }
        return svgColorRegex.matches(in: svg, range: range).allSatisfy { match in
            Range(match.range(at: 1), in: svg).map { isBlack(cssColor: String(svg[$0])) } ?? false
        }
    }

    /// Named colours other than black, and anything else we don't understand, count as not black.
    static func isBlack(cssColor value: String) -> Bool {
        let value = value.lowercased()
            .replacingOccurrences(of: "!important", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        switch value {
        case "none", "transparent", "inherit", "currentcolor", "black":
            // `currentcolor` is black when the image isn't inline in the page, which it never is here.
            return true
        default:
            break
        }

        let channels: [Double]
        if value.hasPrefix("#") {
            let hex = Array(value.dropFirst())
            let digits: [String]
            switch hex.count {
            case 3, 4: digits = hex.prefix(3).map { String([$0, $0]) }
            case 6, 8: digits = stride(from: 0, to: 6, by: 2).map { String(hex[$0 ..< $0 + 2]) }
            default: return false
            }
            let parsed = digits.compactMap { UInt8($0, radix: 16) }.map(Double.init)
            guard parsed.count == 3 else { return false }
            channels = parsed
        } else if value.hasPrefix("rgb"), let open = value.firstIndex(of: "("), let close = value.lastIndex(of: ")"), open < close {
            let components = value[value.index(after: open) ..< close]
                .split(whereSeparator: { $0 == "," || $0 == " " || $0 == "/" })
                .prefix(3)
            let parsed = components.compactMap { component -> Double? in
                if component.hasSuffix("%") {
                    return Double(component.dropLast()).map { $0 * 255 / 100 }
                }
                return Double(component)
            }
            guard parsed.count == 3 else { return false }
            channels = parsed
        } else {
            return false
        }
        return channels.allSatisfy { $0 <= blackThreshold }
    }

    private static func isBlack(raster data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return false }

        let size = 48
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        let drew = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: size,
                height: size,
                bitsPerComponent: 8,
                bytesPerRow: size * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
            return true
        }
        guard drew else { return false }

        // Only look at mostly-opaque pixels; the edges of an anti-aliased shape can be blended with whatever colour was behind it when the image was made.
        var visible = 0
        var notBlack = 0
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Double(pixels[i + 3])
            guard alpha >= 128 else { continue }
            visible += 1
            let brightest = Double(max(pixels[i], pixels[i + 1], pixels[i + 2])) * 255 / alpha
            if brightest > blackThreshold {
                notBlack += 1
            }
        }
        return visible >= 8 && Double(notBlack) <= Double(visible) * 0.03
    }

    /// Channels at or below this still count as black. Dark greys are often used for shading in black icons, and the filters themes use keep that shading visible.
    private static let blackThreshold: Double = 0x40

    /// Classes we style ourselves (e.g. `coder`, with a star before the username), or that the posts view puts on `<post>` elements for its own reasons.
    private static let reservedClasses: Set<String> = [
        "author", "award", "coder", "diamond", "embed-processed", "embed-processing", "idiotking", "ignored", "no-avatar", "op", "platinum", "redpill", "responsive", "seen",
    ]

    private static func isReserved(_ className: String) -> Bool {
        reservedClasses.contains(className.lowercased()) || className.lowercased().hasPrefix("role-")
    }

    private static func sanitizedImageURL(_ raw: String) -> URL? {
        var raw = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.hasPrefix("//") {
            raw = "https:" + raw
        }
        guard var components = URLComponents(string: raw),
              let scheme = components.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              let host = components.host?.lowercased(),
              host == "somethingawful.com" || host.hasSuffix(".somethingawful.com")
        else { return nil }
        components.scheme = "https"
        guard let url = components.url else { return nil }

        // We're going to write this into a quoted CSS string, so make sure it can't escape.
        let unsafe = CharacterSet(charactersIn: "\"'\\()<>{};").union(.whitespacesAndNewlines).union(.controlCharacters)
        guard url.absoluteString.rangeOfCharacter(from: unsafe) == nil else { return nil }
        return url
    }
}

private let commentRegex = try! NSRegularExpression(pattern: #"/\*.*?\*/"#, options: .dotMatchesLineSeparators)
private let ruleRegex = try! NSRegularExpression(pattern: #"([^{}]+)\{([^{}]*)\}"#)
private let backgroundURLRegex = try! NSRegularExpression(pattern: #"background(?:-image)?\s*:[^;]*?url\(\s*['"]?([^'")]+?)['"]?\s*\)"#, options: .caseInsensitive)
private let svgOtherColorSourceRegex = try! NSRegularExpression(pattern: #"<(image|linearGradient|radialGradient|pattern|filter|foreignObject)\b"#, options: .caseInsensitive)
private let svgColorRegex = try! NSRegularExpression(pattern: #"\b(?:fill|stroke|color)\s*[:=]\s*["']?\s*([^;"'}>]+?)\s*(?=["';}>]|/>|$)"#, options: [.caseInsensitive, .anchorsMatchLines])
private let selectorClassRegex = try! NSRegularExpression(pattern: #"\bdt\.([A-Za-z_][A-Za-z0-9_-]*)\s*$"#)
