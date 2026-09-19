//  AppIconDataSource.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulTheming
import os
import SwiftUI

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "AppIconDataSource")

@MainActor public class AppIconDataSource: ObservableObject {
    let appIcons: [AppIcon]
    let imageLoader: (AppIcon) -> Image
    /// Loads the preview for a specific appearance, for the grid's Light/Dark picker.
    /// Defaults to `imageLoader` — i.e. whatever the ambient appearance resolves to.
    let appearanceImageLoader: (AppIcon, Theme.Mode) -> Image
    @Published private(set) var selected: AppIcon
    private let setter: (AppIcon) async throws -> Void

    /// The icon the system last confirmed. `selected` runs ahead of this while a request is
    /// in flight; a failed request falls back to it.
    private var confirmed: AppIcon
    private var selectionTask: Task<Void, Never>?
    /// Incremented per `select(_:)`. A task compares its captured value to this to learn whether
    /// it is still the latest request, since a task can't read its own handle from inside.
    private var selectionGeneration = 0

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
        appearanceImageLoader: ((AppIcon, Theme.Mode) -> Image)? = nil,
        selected: AppIcon,
        setter: @escaping (AppIcon) async throws -> Void
    ) {
        self.appIcons = appIcons
        self.imageLoader = imageLoader
        self.appearanceImageLoader = appearanceImageLoader ?? { icon, _ in imageLoader(icon) }
        self.selected = selected
        self.confirmed = selected
        self.setter = setter
    }

    /// Optimistically selects `appIcon` and asks the system to apply it. Only the latest
    /// request matters: requests are serialised behind the one in flight, a queued request
    /// that is superseded before it starts is skipped, and only the latest request may roll
    /// `selected` back on failure. The setter itself (`setAlternateIconName`) can't be
    /// cancelled, so a superseded request that already started still records its outcome.
    func select(_ appIcon: AppIcon) {
        selected = appIcon
        selectionGeneration += 1
        let generation = selectionGeneration
        let previous = selectionTask
        previous?.cancel()
        selectionTask = Task {
            await previous?.value
            guard !Task.isCancelled else { return }
            do {
                try await setter(appIcon)
                confirmed = appIcon
            } catch {
                logger.error("Could not set app icon to \(appIcon.imageName): \(error)")
                if generation == selectionGeneration {
                    selected = confirmed
                }
            }
            if generation == selectionGeneration {
                selectionTask = nil
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
