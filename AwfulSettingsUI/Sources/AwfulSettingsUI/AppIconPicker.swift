//  AppIconPicker.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import SwiftUI

struct AppIconPicker: View {
    @ObservedObject private var appIconDataSource: AppIconDataSource

    init(appIconDataSource: AppIconDataSource) {
        self.appIconDataSource = appIconDataSource
    }

    struct IconButton: View {
        let image: Image
        let isSelected: Bool
        let select: () -> Void

        var body: some View {
            Button(action: { select() }) {
                VStack {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 60, maxHeight: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(alignment: .bottomTrailing) {
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .resizable()
                                    .frame(width: 24, height: 24)
                                    .foregroundColor(.white)
                                    .offset(x: 2, y: 2)
                            }
                        }
                }
            }
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
    }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack {
                ForEach(appIconDataSource.appIcons) { appIcon in
                    IconButton(
                        image: appIconDataSource.imageLoader(appIcon),
                        isSelected: appIconDataSource.selected == appIcon,
                        select: { appIconDataSource.select(appIcon) }
                    )
                    .accessibilityLabel(appIcon.accessibilityLabel)
                }
            }
        }
    }
}

#Preview {
    AppIconPicker(appIconDataSource: .preview)
}
