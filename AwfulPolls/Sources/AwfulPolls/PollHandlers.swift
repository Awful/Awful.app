//  PollHandlers.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import SwiftUI

/// What the app does on the poll viewer's behalf. Poll options can contain smilies, and the app's
/// smilie machinery (the bundled store and its FLAnimatedImage renderer) sits outside this package,
/// so drawing one stays with the caller.
public struct PollHandlers {

    /// Returns the bundled smilie image for `text` (its text form, e.g. `":q:"`) as animated-image
    /// data plus the image's natural size, or nil if the store doesn't have it.
    public var storedSmilie: @MainActor (_ text: String) -> (data: Data, size: CGSize)?

    /// A view that renders animated image `data` (typically a GIF). `id` uniquely identifies the
    /// image so the renderer can cache decoded frames.
    public var animatedImageView: @MainActor (_ data: Data, _ id: String) -> AnyView

    public init(
        storedSmilie: @escaping @MainActor (_ text: String) -> (data: Data, size: CGSize)?,
        animatedImageView: @escaping @MainActor (_ data: Data, _ id: String) -> AnyView
    ) {
        self.storedSmilie = storedSmilie
        self.animatedImageView = animatedImageView
    }
}
