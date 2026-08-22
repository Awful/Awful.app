//  GlossaryHTMLRenderer.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import HTMLReader

/// Converts a SAclopedia entry's body HTML into a themeable `AttributedString`.
///
/// Handles the markup entries actually use — text, `<br>` line breaks, `<a>` links, and
/// `<b>`/`<i>` emphasis — and gracefully degrades anything else to its text/links by recursing into
/// children. Output is colour-agnostic (links/emphasis are marked with `.link` /
/// `.inlinePresentationIntent`); the view applies theme colours.
enum GlossaryHTMLRenderer {

    static func attributedString(fromHTML html: String, baseURL: URL?) -> AttributedString {
        let document = HTMLDocument(string: html)
        let root: HTMLNode = document.firstNode(matchingSelector: "body") ?? document
        var output = AttributedString()
        for child in childNodes(of: root) {
            append(node: child, to: &output, style: Style(), baseURL: baseURL)
        }
        return trimmedTrailingWhitespace(output)
    }

    private struct Style {
        var bold = false
        var italic = false
        var link: URL?
    }

    private static func append(node: HTMLNode, to output: inout AttributedString, style: Style, baseURL: URL?) {
        if let textNode = node as? HTMLTextNode {
            guard !textNode.data.isEmpty else { return }
            var run = AttributedString(textNode.data)
            var intent: InlinePresentationIntent = []
            if style.bold { intent.insert(.stronglyEmphasized) }
            if style.italic { intent.insert(.emphasized) }
            if !intent.isEmpty { run.inlinePresentationIntent = intent }
            if let link = style.link { run.link = link }
            output.append(run)
            return
        }

        guard let element = node as? HTMLElement else { return }

        var style = style
        switch element.tagName.lowercased() {
        case "br":
            output.append(AttributedString("\n"))
            return
        case "b", "strong":
            style.bold = true
        case "i", "em":
            style.italic = true
        case "a":
            if let href = element["href"], let url = URL(string: href, relativeTo: baseURL)?.absoluteURL {
                style.link = url
            }
        case "p", "div", "blockquote":
            for child in childNodes(of: element) {
                append(node: child, to: &output, style: style, baseURL: baseURL)
            }
            output.append(AttributedString("\n\n"))
            return
        default:
            break
        }

        for child in childNodes(of: element) {
            append(node: child, to: &output, style: style, baseURL: baseURL)
        }
    }

    private static func childNodes(of node: HTMLNode) -> [HTMLNode] {
        (node.children.array as? [HTMLNode]) ?? []
    }

    private static func trimmedTrailingWhitespace(_ input: AttributedString) -> AttributedString {
        var s = input
        while let last = s.characters.last, last.isWhitespace {
            let range = s.characters.index(before: s.endIndex)..<s.endIndex
            s.removeSubrange(range)
        }
        return s
    }
}
