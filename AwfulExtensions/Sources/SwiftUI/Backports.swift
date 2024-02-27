//  Backports.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import SwiftUI

public extension Backport where Content: View {
    /// Sets the font weight of the text in this view.
    @ViewBuilder func fontWeight(_ weight: Font.Weight?) -> some View {
        if #available(iOS 16, *) {
            content.fontWeight(weight)
        } else {
            content
        }
    }

    /// Specifies the visibility of the background for scrollable views within this view.
    @ViewBuilder func scrollContentBackground(_ visibility: Visibility) -> some View {
        if #available(iOS 16, *) {
            content.scrollContentBackground(visibility)
        } else {
            content
        }
    }
}
