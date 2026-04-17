//  RestorableLocation.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

/// A view controller that knows how to express its current location as an `AwfulRoute`,
/// so the scene's `stateRestorationActivity` can be replayed via `AwfulURLRouter` after the
/// system has killed and re-created the scene.
protocol RestorableLocation: AnyObject {
    var restorationRoute: AwfulRoute? { get }
}
