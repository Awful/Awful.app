//  SearchHandlers.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// What the app does on the search screens' behalf. The package stays out of navigation decisions
/// that depend on app-only types: opening a post means building the app's posts screen and choosing
/// where it goes, so both stay with the caller.
public struct SearchHandlers {

    /// Opens the post with the given ID. `from` is the results screen asking; the handler owns any
    /// progress or failure UI, and placement (push vs. detail column) is its call too.
    public var openPost: @MainActor (_ postID: String, _ from: UIViewController) async -> Void

    public init(openPost: @escaping @MainActor (_ postID: String, _ from: UIViewController) async -> Void) {
        self.openPost = openPost
    }
}
