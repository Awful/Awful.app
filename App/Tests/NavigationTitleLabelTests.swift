//  NavigationTitleLabelTests.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulTheming
import UIKit
import XCTest

/// The posts page title's font has to match what it was before it followed the window's width: the same text style, size adjustment and weight from the theme, and the theme's rounded design, through the same `preferredFontForTextStyle` call.
@MainActor
final class NavigationTitleLabelTests: XCTestCase {

    private static let themeNames = [
        "BYOB", "default", "dark", "alternateDefault", "alternateDark", "oledDark", "brightLight", "FYAD",
        "Gas Chamber", "Macinyos", "spankykongDark", "spankykongLight", "Winpos 95", "YOSPOS", "YOSPOS (amber)",
    ]

    /// The font the posts page set before, for a given device style.
    private func expectedFont(for theme: Theme, padStyle: Bool) -> UIFont {
        let suffix = padStyle ? "Pad" : "Phone"
        return UIFont.preferredFontForTextStyle(
            .callout,
            fontName: nil,
            sizeAdjustment: theme[double: "postTitleFontSizeAdjustment\(suffix)"]!,
            weight: FontWeight(rawValue: theme["postTitleFontWeight\(suffix)"]!)!.weight
        )
    }

    /// A label in a window whose width class is overridden, as the posts page's bar would give it.
    private func makeLabel(theme: Theme, horizontalSizeClass: UIUserInterfaceSizeClass) throws -> NavigationTitleLabel {
        guard #available(iOS 17.0, *) else { throw XCTSkip("Needs trait overrides") }
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        window.traitOverrides.horizontalSizeClass = horizontalSizeClass
        window.isHidden = false
        let label = UINavigationItem().titleLabel
        window.addSubview(label)
        label.theme = theme
        window.layoutIfNeeded()
        addTeardownBlock { window.isHidden = true }
        return label
    }

    func testEveryThemeKeepsItsFontAndLineCount() throws {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        for name in Self.themeNames {
            let theme = try XCTUnwrap(Theme.theme(named: name), name)
            for sizeClass in [UIUserInterfaceSizeClass.regular, .compact] {
                let label = try makeLabel(theme: theme, horizontalSizeClass: sizeClass)
                let padStyle = isPad && sizeClass == .regular
                XCTAssertEqual(label.font, expectedFont(for: theme, padStyle: padStyle), "\(name), \(sizeClass == .regular ? "regular" : "compact")")
                XCTAssertEqual(label.numberOfLines, padStyle ? 1 : 2, name)
            }
        }
    }

    func testRestylesWhenTheWindowNarrows() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else { throw XCTSkip("iPad only") }
        guard #available(iOS 17.0, *) else { throw XCTSkip("Needs trait overrides") }
        let theme = try XCTUnwrap(Theme.theme(named: "spankykongLight"))
        let label = try makeLabel(theme: theme, horizontalSizeClass: .regular)
        XCTAssertEqual(label.font, expectedFont(for: theme, padStyle: true))

        label.window?.traitOverrides.horizontalSizeClass = .compact
        label.window?.layoutIfNeeded()

        XCTAssertEqual(label.font, expectedFont(for: theme, padStyle: false))
        XCTAssertEqual(label.numberOfLines, 2)
    }
}
