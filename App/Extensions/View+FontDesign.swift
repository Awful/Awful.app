//  View+FontDesign.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import SwiftUI

extension View {
    @ViewBuilder
    func applyFontDesign(if condition: Bool) -> some View {
        if #available(iOS 16.1, *) {
            self.fontDesign(condition ? .rounded : .default)
        } else {
            self
        }
    }
}
