//  SwiftUIDefaultThemePickerView.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulTheming
import SwiftUI

struct SwiftUIDefaultThemePickerView: View {
    let mode: Theme.Mode
    
    var body: some View {
        SwiftUIThemePickerView(mode: mode)
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.large)
    }
    
    private var navigationTitle: String {
        switch mode {
        case .light:
            return String(localized: "Default Light Theme", bundle: .module)
        case .dark:
            return String(localized: "Default Dark Theme", bundle: .module)
        }
    }
}

#Preview("Light Theme") {
    NavigationView {
        SwiftUIDefaultThemePickerView(mode: .light)
    }
}

#Preview("Dark Theme") {
    NavigationView {
        SwiftUIDefaultThemePickerView(mode: .dark)
    }
}