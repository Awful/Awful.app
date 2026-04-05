//  CustomThemeManager.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

/// Manages user customizations for the custom theme, including native property overrides and custom CSS.
/// Stores data in Application Support/CustomTheme/.
@MainActor
public final class CustomThemeManager: ObservableObject {

    public static let shared = CustomThemeManager()

    /// Sparse dictionary of native theme property overrides (only keys the user has changed).
    @Published public private(set) var overrides: [String: Any] = [:]

    /// Full CSS text for WebView styling. When nil, falls back to the bundled default stylesheet.
    @Published public private(set) var customCSS: String?

    /// The name of the bundled theme used as the starting point, for display purposes.
    @Published public private(set) var baseThemeName: String?

    // MARK: - File paths

    private var storageDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("CustomTheme", isDirectory: true)
    }

    private var jsonFileURL: URL {
        storageDirectory.appendingPathComponent("custom-theme.json")
    }

    private var cssFileURL: URL {
        storageDirectory.appendingPathComponent("custom-posts.css")
    }

    private init() {}

    // MARK: - Load / Save

    /// Loads saved overrides and custom CSS from disk. Call early in app launch.
    public func load() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: storageDirectory.path) else { return }

        // Load JSON overrides
        if let jsonData = fm.contents(atPath: jsonFileURL.path),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            overrides = json["overrides"] as? [String: Any] ?? [:]
            baseThemeName = json["baseThemeName"] as? String
        }

        // Load custom CSS
        if let cssData = fm.contents(atPath: cssFileURL.path) {
            customCSS = String(data: cssData, encoding: .utf8)
        }
    }

    /// Persists current state to disk.
    public func save() {
        let fm = FileManager.default
        try? fm.createDirectory(at: storageDirectory, withIntermediateDirectories: true)

        // Save JSON
        var json: [String: Any] = [:]
        json["overrides"] = overrides
        if let baseThemeName {
            json["baseThemeName"] = baseThemeName
        }
        if let jsonData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) {
            try? jsonData.write(to: jsonFileURL)
        }

        // Save CSS
        if let customCSS {
            try? customCSS.data(using: .utf8)?.write(to: cssFileURL)
        } else {
            try? fm.removeItem(at: cssFileURL)
        }
    }

    // MARK: - Editing

    /// Sets a single native theme property override.
    public func setValue(_ value: Any, forKey key: String) {
        overrides[key] = value
        save()
        Theme.reloadCustomTheme()
    }

    /// Removes a single override, reverting to the bundled default for that key.
    public func removeValue(forKey key: String) {
        overrides.removeValue(forKey: key)
        save()
        Theme.reloadCustomTheme()
    }

    /// Sets the custom CSS text for WebView styling.
    public func setCustomCSS(_ css: String?) {
        customCSS = css
        save()
        Theme.reloadCustomTheme()
    }

    /// Copies all resolved values from a bundled theme into the custom theme.
    /// This walks the parent chain to get every property's effective value.
    /// Keys that should not be copied from a source theme, as they are identity properties of the custom theme.
    private static let excludedKeys: Set<String> = [
        "descriptiveName", "description", "descriptiveColor", "relevantForumID", "parent"
    ]

    public func copyFromTheme(_ theme: Theme) {
        var resolved = theme.allResolvedValues()
        for key in Self.excludedKeys {
            resolved.removeValue(forKey: key)
        }
        overrides = resolved
        baseThemeName = theme.name

        // Load the source theme's compiled CSS
        let cssKey = theme.allResolvedValues()["postsViewCSS"] as? String ?? "posts-view"
        if let url = Bundle.module.url(forResource: cssKey, withExtension: ".css"),
           let css = try? String(contentsOf: url, encoding: .utf8) {
            customCSS = css
        }

        save()
        Theme.reloadCustomTheme()
    }

    /// Resets all customizations, reverting to the bundled customDefault values.
    public func resetToDefaults() {
        overrides = [:]
        customCSS = nil
        baseThemeName = nil
        save()
        Theme.reloadCustomTheme()
    }

    // MARK: - CSS Resolution

    /// Returns the CSS to use for WebViews when the custom theme is active.
    /// Falls back to the bundled default stylesheet if no custom CSS is set.
    public func resolvedCSS() -> String? {
        if let customCSS {
            return customCSS
        }
        // Fall back to the bundled default CSS
        guard let url = Bundle.module.url(forResource: "posts-view", withExtension: ".css"),
              let css = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        return css
    }

    // MARK: - Export

    /// Exports native theme properties as JSON. CSS is exported as a separate .css file.
    public func exportJSON() throws -> Data {
        var export: [String: Any] = [:]
        export["formatVersion"] = 2
        export["exportDate"] = ISO8601DateFormatter().string(from: Date())
        export["hasCustomCSS"] = customCSS != nil

        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            export["appVersion"] = version
        }
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            export["appBuild"] = build
        }
        if let baseThemeName {
            export["baseThemeName"] = baseThemeName
        }

        export["overrides"] = overrides

        return try JSONSerialization.data(withJSONObject: export, options: [.prettyPrinted, .sortedKeys])
    }

    // MARK: - Import

    /// Imports a custom theme from exported JSON data.
    /// Supports format version 1 (CSS inline) and version 2 (CSS separate).
    public func importFromJSON(_ data: Data) throws {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CustomThemeError.invalidFormat
        }

        guard let formatVersion = json["formatVersion"] as? Int, [1, 2].contains(formatVersion) else {
            throw CustomThemeError.unsupportedVersion
        }

        if let importedOverrides = json["overrides"] as? [String: Any] {
            // Validate color hex strings
            for (key, value) in importedOverrides {
                if key.hasSuffix("Color"), let hex = value as? String, !hex.isEmpty {
                    guard isValidHexColor(hex) else {
                        throw CustomThemeError.invalidColorValue(key: key, value: hex)
                    }
                }
            }
            overrides = importedOverrides
        }

        // Format v1 had CSS inline; v2 has it as a separate file
        if formatVersion == 1 {
            customCSS = json["customCSS"] as? String
        }
        // For v2, CSS is imported separately via importCSS(_:)

        baseThemeName = json["baseThemeName"] as? String

        save()
        Theme.reloadCustomTheme()
    }

    /// Imports a CSS stylesheet from file data.
    public func importCSS(_ data: Data) throws {
        guard let css = String(data: data, encoding: .utf8), !css.isEmpty else {
            throw CustomThemeError.invalidFormat
        }
        customCSS = css
        save()
        Theme.reloadCustomTheme()
    }
}

extension CustomThemeManager {
    /// Validates that a string is a valid CSS hex color (e.g., #RGB, #RGBA, #RRGGBB, #RRGGBBAA).
    private func isValidHexColor(_ string: String) -> Bool {
        let hex = string.hasPrefix("#") ? String(string.dropFirst()) : string
        guard hex.allSatisfy(\.isHexDigit) else { return false }
        return [3, 4, 6, 8].contains(hex.count)
    }
}

public enum CustomThemeError: LocalizedError {
    case invalidFormat
    case unsupportedVersion
    case invalidColorValue(key: String, value: String)

    public var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "The file is not a valid theme export."
        case .unsupportedVersion:
            return "This theme was exported from a newer version of the app."
        case .invalidColorValue(let key, let value):
            return "Invalid color value '\(value)' for key '\(key)'."
        }
    }
}
