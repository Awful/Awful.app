//  HiddenScrollBackground.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import SwiftUI

/// Wraps `.scrollContentBackground(.hidden)` (iOS 16+) so the themed background shows through the
/// list; a no-op on iOS 15.
struct HiddenScrollBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollContentBackground(.hidden)
        } else {
            content
        }
    }
}
