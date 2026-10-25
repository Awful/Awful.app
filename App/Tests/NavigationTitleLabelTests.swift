//  NavigationTitleLabelTests.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulTheming
import UIKit
import XCTest

/// The posts page title takes the callout text style with the theme's `postTitleFontSizeAdjustment` and `postTitleFontWeight`, the `Pad` keys on an iPad at regular width and the `Phone` keys otherwise, on one line or two to match.
@MainActor
final class NavigationTitleLabelTests: XCTestCase {

    /// The title font a theme gives the iPad or iPhone style.
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

    func testEveryThemeSetsTheTitleFontAndLineCount() throws {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        for theme in Theme.allThemes {
            let name = theme.name
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
