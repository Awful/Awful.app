//  AppIconGridView.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulTheming
import SwiftUI

struct AppIconGridView: View {
    @ObservedObject var appIconDataSource: AppIconDataSource
    @SwiftUI.Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @SwiftUI.Environment(\.theme) var theme
    /// Which appearance the previews render in. Affects the icon art only, never the chrome.
    @State private var previewMode: Theme.Mode = .light

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
            VStack(spacing: 0) {
                LazyVGrid(columns: columns, spacing: 30) {
                    ForEach(appIconDataSource.appIcons) { appIcon in
                        IconCell(
                            image: appIconDataSource.appearanceImageLoader(appIcon, previewMode),
                            isSelected: appIconDataSource.selected == appIcon,
                            select: {
                                appIconDataSource.select(appIcon)
                            }
                        )
                        .accessibilityLabel(appIcon.accessibilityLabel)
                    }
                }
                .padding()
                .padding(.top, 5)

                appearancePicker
            }
        }
        .background(theme[color: "sheetBackgroundColor"]!)
        .navigationTitle(Text("App Icon", bundle: .module))
        .foregroundStyle(theme[color: "sheetTitleColor"]!)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var appearancePicker: some View {
        // The `label:`-as-a-value initializer, not the trailing-closure one, which is iOS 16+.
        // The segmented style doesn't render the label; it's here for VoiceOver.
        Picker(selection: $previewMode, label: Text("Preview appearance", bundle: .module)) {
            ForEach(Theme.Mode.allCases, id: \.self) { mode in
                Text(mode.localizedDescription).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .tint(theme[color: "tintColor"])
        .frame(maxWidth: 260)
        // Sits just below the grid rather than pinned to the bottom of the screen, so it
        // stays next to the icons on tall, narrow layouts like the iPad portrait sidebar.
        .padding(.top, 30)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
    }
}

private struct IconCell: View {
    let image: Image
    let isSelected: Bool
    let select: () -> Void
    @SwiftUI.Environment(\.theme) private var theme

    private let iconSize: CGFloat = 70
    private let iconRadius: CGFloat = 13
    private let ringGap: CGFloat = 6      // visible gap, icon edge → inner edge of ring
    private let ringWidth: CGFloat = 2.5
    /// How far the stroke's centre path sits outside the icon. The half-width term is what
    /// makes the gap read as the full `ringGap`, since `.stroke` straddles its path.
    private var ringInset: CGFloat { ringGap + ringWidth / 2 }

    var body: some View {
        Button(action: select) {
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: iconSize, height: iconSize)
                .clipShape(RoundedRectangle(cornerRadius: iconRadius))
                .overlay(
                    // Negative padding pushes the ring outside the icon without affecting
                    // layout — an overlay is sized by its base and never grows it.
                    RoundedRectangle(cornerRadius: iconRadius + ringInset)
                        .stroke(isSelected ? theme[color: "tabBarIconSelectedColor"]! : .clear, lineWidth: ringWidth)
                        .padding(-ringInset)
                )
                .contentShape(RoundedRectangle(cornerRadius: iconRadius))
        }
        .buttonStyle(PlainButtonStyle())
        // Carries the full selection semantics now that the checkmark is gone.
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    NavigationView {
        AppIconGridView(appIconDataSource: .preview)
    }
}
