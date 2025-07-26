//  NavigationHeaderView.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import SwiftUI
import AwfulTheming

/// Shared navigation header component for consistent styling across all tabs
struct NavigationHeaderView: View {
    let title: String
    let leftButton: HeaderButton?
    let rightButton: HeaderButton?
    
    @SwiftUI.Environment(\.theme) private var theme
    
    init(title: String, leftButton: HeaderButton? = nil, rightButton: HeaderButton? = nil) {
        self.title = title
        self.leftButton = leftButton
        self.rightButton = rightButton
    }
    
    var body: some View {
        HStack {
            // Left button or spacer
            HStack {
                if let leftButton = leftButton {
                    Button(action: leftButton.action) {
                        buttonContent(for: leftButton)
                    }
                    .foregroundColor(theme[color: "navigationBarTextColor"] ?? .primary)
                }
            }
            .frame(width: 60, alignment: .leading)
            
            Spacer()
            
            // Title
            Text(title)
                .font(.headline)
                .foregroundColor(theme[color: "navigationBarTextColor"] ?? .primary)
                .lineLimit(1)
                .frame(height: 22)
            
            Spacer()
            
            // Right button or spacer
            HStack {
                if let rightButton = rightButton {
                    Button(action: rightButton.action) {
                        buttonContent(for: rightButton)
                    }
                    .foregroundColor(theme[color: "navigationBarTextColor"] ?? .primary)
                }
            }
            .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 16)
        .background(Color(theme[uicolor: "navigationBarTintColor"] ?? UIColor.systemBackground))
    }
    
    @ViewBuilder
    private func buttonContent(for button: HeaderButton) -> some View {
        switch button.type {
        case .text(let text):
            Text(text)
                .frame(height: 22)
        case .image(let imageName):
            Image(imageName)
                .renderingMode(.template)
                .font(.title2)
                .frame(width: 28, height: 28)
        case .systemImage(let systemName):
            Image(systemName: systemName)
                .font(.title2)
                .frame(width: 28, height: 28)
        }
    }
}

/// Configuration for header buttons
struct HeaderButton {
    let type: ButtonType
    let action: () -> Void
    
    enum ButtonType {
        case text(String)
        case image(String)
        case systemImage(String)
    }
    
    init(text: String, action: @escaping () -> Void) {
        self.type = .text(text)
        self.action = action
    }
    
    init(image: String, action: @escaping () -> Void) {
        self.type = .image(image)
        self.action = action
    }
    
    init(systemImage: String, action: @escaping () -> Void) {
        self.type = .systemImage(systemImage)
        self.action = action
    }
}

#Preview {
    NavigationHeaderView(
        title: "Sample Header",
        leftButton: HeaderButton(text: "Edit") { },
        rightButton: HeaderButton(image: "compose") { }
    )
    .themed()
}