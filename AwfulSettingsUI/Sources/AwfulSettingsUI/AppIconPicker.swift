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
        let appIconName: AppIconDataSource.AppIconName
        @Environment(\.colorScheme) var colorScheme
        let image: Image
        let isSelected: Bool
        let select: () -> Void

        var body: some View {
            Button(action: { select() }) {
                image
                    .resizable()
                    .frame(width: 57, height: 57)
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
    }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack {
                ForEach(appIconDataSource.appIcons, id: \.rawValue) { appIcon in
                    if let image = appIconDataSource.image(for: appIcon) {
                        IconButton(
                            appIconName: appIcon,
                            image: image,
                            isSelected: appIconDataSource.selectedIconName == appIcon,
                            select: { appIconDataSource.select(appIcon) }
                        )
                    }
                }
            }
        }
    }
}

@MainActor public class AppIconDataSource: ObservableObject {
    @Published var appIcons: [AppIconName] = []
    let iconsLoader: () async -> [AppIconName]
    let imageLoader: (AppIconName) -> Image?
    @Published private(set) var selectedIconName: AppIconName?
    let setCurrentIconName: (AppIconName?) async throws -> Void

    public struct AppIconName: Hashable, LosslessStringConvertible {
        public let rawValue: String
        public init(_ rawValue: String) {
            self.rawValue = rawValue
        }
        public var description: String { rawValue }
    }

    public init(
        iconsLoader: @escaping () async -> [AppIconName],
        imageLoader: @escaping (AppIconName) -> Image?,
        selectedIconName: AppIconName?,
        setCurrentIconName: @escaping (AppIconName?) async throws -> Void
    ) {
        self.iconsLoader = iconsLoader
        self.imageLoader = imageLoader
        self.selectedIconName = selectedIconName
        self.setCurrentIconName = setCurrentIconName
    }

    @MainActor public func loadAppIcons() async {
        appIcons = await iconsLoader()
        if selectedIconName == nil {
            selectedIconName = appIcons.first
        }
    }

    func image(for appIcon: AppIconName) -> Image? {
        imageLoader(appIcon)
    }

    func select(_ appIcon: AppIconName) {
        let revert = selectedIconName
        // Assume the first icon is the "primary", which UIApplication calls `nil`.
        // Probably makes more sense to bake this knowledge into the passed-in blocks.
        let target = appIcon == appIcons.first ? nil : appIcon
        selectedIconName = appIcon
        Task {
            do {
                try await setCurrentIconName(target)
            } catch {
                print("Could not set alternate app icon to \(target as Any), reverting to \(revert as Any): \(error)")
                selectedIconName = revert
            }
        }
    }
}

#Preview {
    let dataSource = AppIconDataSource(
        iconsLoader: { (1...).prefix(12).map { .init("test\($0)") } },
        imageLoader: { _ in Image(systemName: "questionmark.app.fill") },
        selectedIconName: .init("test2"),
        setCurrentIconName: { _ in }
    )
    return AppIconPicker(appIconDataSource: dataSource)
        .task { await dataSource.loadAppIcons() }
}
