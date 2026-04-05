//  SettingsExporter.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

/// Exports and imports user preferences as JSON for backup/sharing.
public enum SettingsExporter {

    /// Current schema version for exported settings files.
    private static let schemaVersion = 1

    /// All preference keys that should be included in an export.
    /// Session/auth keys (userID, username, etc.) are intentionally excluded.
    private static let preferenceKeys: [String] = [
        Settings.appIconName.key,
        Settings.autoDarkTheme.key,
        Settings.automaticTimg.key,
        Settings.autoplayGIFs.key,
        Settings.bookmarksSortedUnread.key,
        Settings.clipboardURLEnabled.key,
        Settings.confirmBeforeReplying.key,
        Settings.darkMode.key,
        Settings.defaultBrowser.key,
        Settings.defaultDarkThemeName.key,
        Settings.defaultLightThemeName.key,
        Settings.embedBlueskyPosts.key,
        Settings.embedTweets.key,
        Settings.enableCustomTitlePostLayout.key,
        Settings.enableHaptics.key,
        Settings.fontScale.key,
        Settings.forumThreadsSortedUnread.key,
        Settings.frogAndGhostEnabled.key,
        Settings.handoffEnabled.key,
        Settings.hideSidebarInLandscape.key,
        Settings.jumpToPostEndOnDoubleTap.key,
        Settings.loadImages.key,
        Settings.openTwitterLinksInTwitter.key,
        Settings.openYouTubeLinksInYouTube.key,
        Settings.pullForNext.key,
        Settings.showAvatars.key,
        Settings.showThreadTags.key,
        Settings.showUnreadAnnouncementsBadge.key,
        Settings.useNewSmiliePicker.key,
    ]

    /// Exports the current user preferences as JSON data.
    ///
    /// Includes all preference keys and any forum-specific theme overrides
    /// (keys matching the pattern `theme-light-*` or `theme-dark-*`).
    public static func exportSettings(
        defaults: UserDefaults = .standard
    ) throws -> Data {
        var exported: [String: Any] = [
            "_version": schemaVersion,
            "_exportDate": ISO8601DateFormatter().string(from: Date()),
            "_buildNumber": Bundle.main.version ?? "unknown",
        ]

        // Collect known preference keys
        for key in preferenceKeys {
            if let value = defaults.object(forKey: key) {
                exported[key] = value
            }
        }

        // Collect forum-specific theme keys (theme-light-*, theme-dark-*)
        let allKeys = defaults.dictionaryRepresentation()
        for (key, value) in allKeys {
            if isForumSpecificThemeKey(key) {
                exported[key] = value
            }
        }

        return try JSONSerialization.data(
            withJSONObject: exported,
            options: [.prettyPrinted, .sortedKeys]
        )
    }

    /// The result of importing settings, including any warnings.
    public struct ImportResult {
        /// Number of settings that were applied.
        public let appliedCount: Int
        /// Keys present in the current app but missing from the imported file.
        public let missingKeys: [String]
        /// The build number the file was exported from, if available.
        public let exportBuildNumber: String?
        /// Whether the file was exported from an older build than the current app.
        public let isOlderBuild: Bool
    }

    /// Imports settings from JSON data, applying them to UserDefaults.
    ///
    /// - Parameters:
    ///   - data: The JSON data previously exported by `exportSettings`.
    ///   - validThemeNames: If provided, theme values will be validated against this set.
    ///   - defaults: The UserDefaults store to write to.
    /// - Returns: An `ImportResult` with the count of applied settings and any warnings.
    public static func importSettings(
        from data: Data,
        validThemeNames: Set<String>? = nil,
        defaults: UserDefaults = .standard
    ) throws -> ImportResult {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ImportError.invalidFormat
        }

        guard let version = json["_version"] as? Int else {
            throw ImportError.missingVersion
        }
        guard version <= schemaVersion else {
            throw ImportError.unsupportedVersion(version)
        }

        let exportBuildNumber = json["_buildNumber"] as? String
        let currentBuildNumber = Bundle.main.version
        let isOlderBuild: Bool = {
            guard let exported = exportBuildNumber,
                  let current = currentBuildNumber,
                  let exportedInt = Int(exported),
                  let currentInt = Int(current)
            else { return false }
            return exportedInt < currentInt
        }()

        let knownKeys = Set(preferenceKeys)
        let importedSettingKeys = Set(json.keys.filter { !$0.hasPrefix("_") })
        var appliedCount = 0

        for (key, value) in json {
            // Skip metadata keys
            if key.hasPrefix("_") { continue }

            // Only import known preference keys or forum-specific theme keys
            guard knownKeys.contains(key) || isForumSpecificThemeKey(key) else { continue }

            // Validate theme values if a validation set is provided
            if let validNames = validThemeNames, isThemeValueKey(key) {
                if let themeName = value as? String, !validNames.contains(themeName) {
                    continue
                }
            }

            defaults.set(value, forKey: key)
            appliedCount += 1
        }

        // Find preference keys that exist in the current app but were missing from the file
        let missingKeys = preferenceKeys.filter { !importedSettingKeys.contains($0) }

        return ImportResult(
            appliedCount: appliedCount,
            missingKeys: missingKeys,
            exportBuildNumber: exportBuildNumber,
            isOlderBuild: isOlderBuild
        )
    }

    private static func isForumSpecificThemeKey(_ key: String) -> Bool {
        let parts = key.split(separator: "-")
        guard
            parts.count == 3,
            parts[0] == "theme",
            parts[1] == "light" || parts[1] == "dark",
            Int(parts[2]) != nil
        else { return false }
        return true
    }

    private static func isThemeValueKey(_ key: String) -> Bool {
        key == Settings.defaultDarkThemeName.key
            || key == Settings.defaultLightThemeName.key
            || isForumSpecificThemeKey(key)
    }

    public enum ImportError: LocalizedError {
        case invalidFormat
        case missingVersion
        case unsupportedVersion(Int)

        public var errorDescription: String? {
            switch self {
            case .invalidFormat:
                return "The file is not a valid Awful settings file."
            case .missingVersion:
                return "The settings file is missing a version number."
            case .unsupportedVersion(let version):
                return "This settings file (version \(version)) was created by a newer version of Awful."
            }
        }
    }
}
