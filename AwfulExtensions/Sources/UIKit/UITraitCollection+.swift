//  UITraitCollection+.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

public extension UITraitCollection {
    /// Whether these are an iPad's traits at a width laid out like an iPad, rather than a window narrow enough to be compact width, which is laid out like an iPhone. A size class not yet known counts as wide.
    ///
    /// A screen in a sheet asks its window's traits, as a sheet on iPad is compact width whatever the window's width.
    var isRegularWidthPad: Bool {
        userInterfaceIdiom == .pad && horizontalSizeClass != .compact
    }
}
