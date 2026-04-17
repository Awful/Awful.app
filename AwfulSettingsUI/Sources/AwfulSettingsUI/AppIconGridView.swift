//  AppIconGridView.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulTheming
import SwiftUI

struct AppIconGridView: View {
    @ObservedObject var appIconDataSource: AppIconDataSource
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @SwiftUI.Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @SwiftUI.Environment(\.theme) var theme
    
    init(appIconDataSource: AppIconDataSource) {
        self.appIconDataSource = appIconDataSource
    }
    
    private var columns: [GridItem] {
        let count = horizontalSizeClass == .regular ? 4 : 3
        let spacing: CGFloat = 30  // horizontal spacing between icons (matches vertical)
        return Array(repeating: GridItem(.fixed(70), spacing: spacing), count: count)
    }
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 30) {
                ForEach(appIconDataSource.appIcons) { appIcon in
                    IconCell(
                        image: appIconDataSource.imageLoader(appIcon),
                        isSelected: appIconDataSource.selected == appIcon,
                        select: {
                            appIconDataSource.select(appIcon)
                        }
                    )
                    .accessibilityLabel(appIcon.accessibilityLabel)
                }
            }
            .padding()
        }
        .background(theme[color: "sheetBackgroundColor"]!)
        .navigationTitle(Text("App Icon", bundle: .module))
        .foregroundStyle(theme[color: "sheetTitleColor"]!)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Text("Done", bundle: .module)
                        .fontWeight(.semibold)
                        .foregroundStyle(theme[color: "sheetTitleColor"]!)
                }
            }
        }
    }
}

private struct IconCell: View {
    let image: Image
    let isSelected: Bool
    let select: () -> Void
    
    var body: some View {
        Button(action: select) {
            ZStack {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 70, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 13))
                    .overlay(
                        RoundedRectangle(cornerRadius: 13)
                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2.5)
                    )
                
                if isSelected {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .resizable()
                                .frame(width: 24, height: 24)
                                .foregroundColor(.white)
                                .background(
                                    Circle()
                                        .fill(Color.accentColor)
                                        .frame(width: 22, height: 22)
                                )
                                .offset(x: -2, y: -2)
                        }
                    }
                }
            }
            .frame(width: 70, height: 70)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    NavigationView {
        AppIconGridView(appIconDataSource: .preview)
    }
}
