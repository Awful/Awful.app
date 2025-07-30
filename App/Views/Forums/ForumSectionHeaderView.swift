//  ForumSectionHeaderView.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulTheming
import SwiftUI

struct ForumSectionHeaderView: View {
    let title: String
    @SwiftUI.Environment(\.theme) private var theme
    
    var body: some View {
        HStack {
            Text(title)
                .font(.preferredFont(forTextStyle: .body, fontName: theme["listFontName"], weight: .regular))
                .foregroundColor(theme[color: "listHeaderTextColor"] ?? Color.primary)
                .textCase(nil)
                .padding(.leading, 16)
            
            Spacer()
        }
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .background(theme[color: "listHeaderBackgroundColor"] ?? Color.gray)
        .listRowInsets(EdgeInsets())
        .listSectionSeparator(.hidden)
    }
}

// MARK: - Preview

struct ForumSectionHeaderView_Previews: PreviewProvider {
    static var previews: some View {
        ForumSectionHeaderView(title: "Favorite Forums")
            .themed()
            .previewLayout(.sizeThatFits)
    }
}
