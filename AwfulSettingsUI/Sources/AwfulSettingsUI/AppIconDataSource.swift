//  AppIconDataSource.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Logger
import SwiftUI

private let Log = Logger.get()

@MainActor public class AppIconDataSource: ObservableObject {
    let appIcons: [AppIcon]
    let imageLoader: (AppIcon) -> Image
    @Published private(set) var selected: AppIcon
    private let setter: (AppIcon) async throws -> Void

    public struct AppIcon: Equatable, Identifiable {
        public let accessibilityLabel: String
        public let imageName: String

        public init(accessibilityLabel: String, imageName: String) {
            self.accessibilityLabel = accessibilityLabel
            self.imageName = imageName
        }

        public var id: String { imageName }
    }

    public init(
        appIcons: [AppIcon],
        imageLoader: @escaping (AppIcon) -> Image,
        selected: AppIcon,
        setter: @escaping (AppIcon) async throws -> Void
    ) {
        self.appIcons = appIcons
        self.imageLoader = imageLoader
        self.selected = selected
        self.setter = setter
    }

    func select(_ appIcon: AppIcon) {
        Task {
            do {
                try await setter(appIcon)
                selected = appIcon
            } catch {
                Log.e("Could not set app icon: \(error)")
            }
        }
    }
}

extension AppIconDataSource {
    static var preview: AppIconDataSource {
        let appIcons = (1...12).map { AppIcon(accessibilityLabel: "\($0)", imageName: "\($0)") }
        return AppIconDataSource(
            appIcons: appIcons,
            imageLoader: { _ in Image(systemName: "questionmark.app.fill") },
            selected: appIcons.first!,
            setter: { _ in }
        )
    }
}
