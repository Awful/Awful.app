//  SpecsReport.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulExtensions
import AwfulSettings
import AwfulTheming
import Foil
import UIKit

/**
 Builds the plain-text device/app diagnostics that the Specs toolbar button appends to a reply in
 the app's feedback thread, so bug reports arrive with enough context to reproduce them.

 Everything in the report is visible in the composition text view before posting, so the user can
 review, edit, or delete any of it.
 */
@MainActor
struct SpecsReport {

    /// The OS-level appearance (what Settings.app calls Dark Mode), as distinct from the app's own
    /// theme. Pass the window's trait so per-view overrides don't leak in.
    var systemInterfaceStyle: UIUserInterfaceStyle = .unspecified

    var text: String {
        var lines = [
            "---",
            "Awful \(appVersionLine)",
            "\(deviceModel), iOS \(UIDevice.current.systemVersion)",
            "System appearance: \(systemInterfaceStyleLabel)",
            "Text size: \(contentSizeCategoryLabel)",
            "Theme: \(themeLine)",
        ]
        let changed = nonDefaultSettingLines
        if changed.isEmpty {
            lines.append("Settings: all defaults")
        } else {
            lines.append("Non-default settings:")
            lines.append(contentsOf: changed)
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Components

    private var appVersionLine: String {
        let version = Bundle.main.shortVersionString ?? "unknown"
        let build = Bundle.main.version ?? "unknown"
        let channel = Environment.isDebugBuild ? " (debug)"
            : Environment.isInstalledViaTestFlight ? " (TestFlight)"
            : ""
        return "\(version) (\(build))\(channel)"
    }

    /// The device's marketing name and model identifier (e.g. "iPhone 15 Pro (iPhone16,1)"),
    /// which pins down the exact hardware in a way UIDevice's marketing-free "iPhone" can't.
    private var deviceModel: String {
        #if targetEnvironment(simulator)
        let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "unknown"
        return "Simulator: \(Self.deviceDescription(forModelIdentifier: simulated))"
        #else
        var systemInfo = utsname()
        uname(&systemInfo)
        let identifier = withUnsafeBytes(of: &systemInfo.machine) { buffer in
            String(decoding: buffer.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
        return Self.deviceDescription(forModelIdentifier: identifier)
        #endif
    }

    /// Returns "iPhone 17 Pro (iPhone18,1)" when the identifier is known, or the bare identifier
    /// when it isn't (there's no public API for the marketing name, so new devices show up raw
    /// until `deviceNames` learns about them).
    private static func deviceDescription(forModelIdentifier identifier: String) -> String {
        guard let name = deviceNames[identifier] else { return identifier }
        return "\(name) (\(identifier))"
    }

    private var systemInterfaceStyleLabel: String {
        switch systemInterfaceStyle {
        case .dark: "dark"
        case .light: "light"
        default: "unknown"
        }
    }

    private var contentSizeCategoryLabel: String {
        // e.g. "UICTContentSizeCategoryL" -> "L", "…AccessibilityXL" -> "AccessibilityXL"
        let raw = UIApplication.shared.preferredContentSizeCategory.rawValue
        let prefix = "UICTContentSizeCategory"
        return raw.hasPrefix(prefix) ? String(raw.dropFirst(prefix.count)) : raw
    }

    private var themeLine: String {
        let defaults = UserDefaults.standard
        let isDark = defaults.defaultingValue(for: Settings.darkMode)
        let auto = defaults.defaultingValue(for: Settings.autoDarkTheme)
        let theme = Theme.defaultTheme(mode: isDark ? .dark : .light)
        return "\(theme.descriptiveName) (\(isDark ? "dark" : "light")\(auto ? ", auto" : ""))"
    }

    private var nonDefaultSettingLines: [String] {
        let defaults = UserDefaults.standard
        return Self.reportableSettings.compactMap { $0.line(defaults) }
    }
}

/// One row in the specs report's settings section, type-erased over `Setting<T>`.
private struct ReportableSetting {
    let line: (UserDefaults) -> String?

    /// Compares the raw stored plist value against the setting's default without constructing the
    /// setting's Swift type, so a stale stored value (e.g. a renamed theme) can't crash the report.
    /// Foil registers each wrapped setting's default, and the registered value equals
    /// `default.storedValue`, so untouched settings compare equal and are omitted.
    init<T: UserDefaultsSerializable>(_ setting: Setting<T>) where T.StoredValue: Equatable {
        line = { defaults in
            guard let stored = defaults.object(forKey: setting.key) as? T.StoredValue,
                  stored != setting.default.storedValue
            else { return nil }
            return "\(setting.key): \(stored)"
        }
    }

    /// For optional string settings, which have no registered default; any stored value is
    /// non-default.
    init(optional setting: Setting<String?>) {
        line = { defaults in
            defaults.string(forKey: setting.key).map { "\(setting.key): \($0)" }
        }
    }
}

extension SpecsReport {
    /**
     Every user-preference setting, excluding session/identity keys (the `sessionKeys` in
     AwfulSettings: userID, username, canSendPrivateMessages, hasPlatinum, hasArchives, hasNoAds,
     lastOfferedPasteboardURLString, imgurUploadMode).

     Per-forum theme overrides (`theme-<mode>-<forumID>` keys written by `Theme.setThemeName`) live
     outside the `Settings` namespace and aren't listed; the four named forum theme settings are.

     KEEP IN SYNC with the `Settings` namespace when adding settings.
     */
    fileprivate static let reportableSettings: [ReportableSetting] = [
        .init(optional: Settings.appIconName),
        .init(Settings.autoDarkTheme),
        .init(Settings.automaticTimg),
        .init(Settings.autoplayGIFs),
        .init(Settings.bookmarksSortedUnread),
        .init(Settings.cleanPastedURLs),
        .init(Settings.clipboardURLEnabled),
        .init(Settings.confirmBeforeReplying),
        .init(Settings.darkMode),
        .init(Settings.defaultBrowser),
        .init(Settings.defaultDarkThemeName),
        .init(Settings.defaultLightThemeName),
        .init(Settings.disableLiquidGlass),
        .init(Settings.embedBlueskyPosts),
        .init(Settings.embedTweets),
        .init(Settings.embedVideos),
        .init(Settings.enableCustomTitlePostLayout),
        .init(Settings.enableHaptics),
        .init(Settings.endlessScrollLepers),
        .init(Settings.endlessScrollPosts),
        .init(Settings.fontScale),
        .init(Settings.forumThreadsSortedUnread),
        .init(Settings.frogAndGhostEnabled),
        .init(Settings.handoffEnabled),
        .init(Settings.hidePostMetadataForReader),
        .init(Settings.hideSidebarInLandscape),
        .init(Settings.imageViewerFullScreen),
        .init(Settings.immersiveModeEnabled),
        .init(Settings.jumpToPostEndOnDoubleTap),
        .init(Settings.loadImages),
        .init(Settings.openTwitterLinksInTwitter),
        .init(Settings.openYouTubeLinksInYouTube),
        .init(Settings.pullForNext),
        .init(Settings.restoreLastThreadOnLaunch),
        .init(Settings.showAvatars),
        .init(Settings.showThreadTags),
        .init(Settings.showUnreadAnnouncementsBadge),
        .init(Settings.themeBYOB),
        .init(Settings.themeFYAD),
        .init(Settings.themeGasChamber),
        .init(Settings.themeYOSPOS),
        .init(Settings.tiltScrollEnabled),
        .init(Settings.tiltScrollInverted),
        .init(Settings.tiltScrollSensitivity),
        .init(Settings.useNewSmiliePicker),
    ]
}

extension SpecsReport {
    /**
     Marketing names for model identifiers, since there's no public API for them. Covers devices
     that can run the app's minimum iOS version (currently iOS 15: iPhone 6s and later, iPad Air 2
     and iPad mini 4 and later). An unknown identifier is reported bare, so a missing entry only
     costs readability.

     KEEP IN SYNC with new hardware as Apple releases it.
     */
    fileprivate static let deviceNames: [String: String] = [
        // iPhone
        "iPhone8,1": "iPhone 6s",
        "iPhone8,2": "iPhone 6s Plus",
        "iPhone8,4": "iPhone SE (1st generation)",
        "iPhone9,1": "iPhone 7",
        "iPhone9,3": "iPhone 7",
        "iPhone9,2": "iPhone 7 Plus",
        "iPhone9,4": "iPhone 7 Plus",
        "iPhone10,1": "iPhone 8",
        "iPhone10,4": "iPhone 8",
        "iPhone10,2": "iPhone 8 Plus",
        "iPhone10,5": "iPhone 8 Plus",
        "iPhone10,3": "iPhone X",
        "iPhone10,6": "iPhone X",
        "iPhone11,2": "iPhone XS",
        "iPhone11,4": "iPhone XS Max",
        "iPhone11,6": "iPhone XS Max",
        "iPhone11,8": "iPhone XR",
        "iPhone12,1": "iPhone 11",
        "iPhone12,3": "iPhone 11 Pro",
        "iPhone12,5": "iPhone 11 Pro Max",
        "iPhone12,8": "iPhone SE (2nd generation)",
        "iPhone13,1": "iPhone 12 mini",
        "iPhone13,2": "iPhone 12",
        "iPhone13,3": "iPhone 12 Pro",
        "iPhone13,4": "iPhone 12 Pro Max",
        "iPhone14,4": "iPhone 13 mini",
        "iPhone14,5": "iPhone 13",
        "iPhone14,2": "iPhone 13 Pro",
        "iPhone14,3": "iPhone 13 Pro Max",
        "iPhone14,6": "iPhone SE (3rd generation)",
        "iPhone14,7": "iPhone 14",
        "iPhone14,8": "iPhone 14 Plus",
        "iPhone15,2": "iPhone 14 Pro",
        "iPhone15,3": "iPhone 14 Pro Max",
        "iPhone15,4": "iPhone 15",
        "iPhone15,5": "iPhone 15 Plus",
        "iPhone16,1": "iPhone 15 Pro",
        "iPhone16,2": "iPhone 15 Pro Max",
        "iPhone17,3": "iPhone 16",
        "iPhone17,4": "iPhone 16 Plus",
        "iPhone17,1": "iPhone 16 Pro",
        "iPhone17,2": "iPhone 16 Pro Max",
        "iPhone17,5": "iPhone 16e",
        "iPhone18,1": "iPhone 17 Pro",
        "iPhone18,2": "iPhone 17 Pro Max",
        "iPhone18,3": "iPhone 17",
        "iPhone18,4": "iPhone Air",

        // iPod touch
        "iPod9,1": "iPod touch (7th generation)",

        // iPad
        "iPad5,1": "iPad mini 4",
        "iPad5,2": "iPad mini 4",
        "iPad5,3": "iPad Air 2",
        "iPad5,4": "iPad Air 2",
        "iPad6,3": "iPad Pro (9.7-inch)",
        "iPad6,4": "iPad Pro (9.7-inch)",
        "iPad6,7": "iPad Pro (12.9-inch)",
        "iPad6,8": "iPad Pro (12.9-inch)",
        "iPad6,11": "iPad (5th generation)",
        "iPad6,12": "iPad (5th generation)",
        "iPad7,1": "iPad Pro (12.9-inch) (2nd generation)",
        "iPad7,2": "iPad Pro (12.9-inch) (2nd generation)",
        "iPad7,3": "iPad Pro (10.5-inch)",
        "iPad7,4": "iPad Pro (10.5-inch)",
        "iPad7,5": "iPad (6th generation)",
        "iPad7,6": "iPad (6th generation)",
        "iPad7,11": "iPad (7th generation)",
        "iPad7,12": "iPad (7th generation)",
        "iPad8,1": "iPad Pro (11-inch)",
        "iPad8,2": "iPad Pro (11-inch)",
        "iPad8,3": "iPad Pro (11-inch)",
        "iPad8,4": "iPad Pro (11-inch)",
        "iPad8,5": "iPad Pro (12.9-inch) (3rd generation)",
        "iPad8,6": "iPad Pro (12.9-inch) (3rd generation)",
        "iPad8,7": "iPad Pro (12.9-inch) (3rd generation)",
        "iPad8,8": "iPad Pro (12.9-inch) (3rd generation)",
        "iPad8,9": "iPad Pro (11-inch) (2nd generation)",
        "iPad8,10": "iPad Pro (11-inch) (2nd generation)",
        "iPad8,11": "iPad Pro (12.9-inch) (4th generation)",
        "iPad8,12": "iPad Pro (12.9-inch) (4th generation)",
        "iPad11,1": "iPad mini (5th generation)",
        "iPad11,2": "iPad mini (5th generation)",
        "iPad11,3": "iPad Air (3rd generation)",
        "iPad11,4": "iPad Air (3rd generation)",
        "iPad11,6": "iPad (8th generation)",
        "iPad11,7": "iPad (8th generation)",
        "iPad12,1": "iPad (9th generation)",
        "iPad12,2": "iPad (9th generation)",
        "iPad13,1": "iPad Air (4th generation)",
        "iPad13,2": "iPad Air (4th generation)",
        "iPad13,4": "iPad Pro (11-inch) (3rd generation)",
        "iPad13,5": "iPad Pro (11-inch) (3rd generation)",
        "iPad13,6": "iPad Pro (11-inch) (3rd generation)",
        "iPad13,7": "iPad Pro (11-inch) (3rd generation)",
        "iPad13,8": "iPad Pro (12.9-inch) (5th generation)",
        "iPad13,9": "iPad Pro (12.9-inch) (5th generation)",
        "iPad13,10": "iPad Pro (12.9-inch) (5th generation)",
        "iPad13,11": "iPad Pro (12.9-inch) (5th generation)",
        "iPad13,16": "iPad Air (5th generation)",
        "iPad13,17": "iPad Air (5th generation)",
        "iPad13,18": "iPad (10th generation)",
        "iPad13,19": "iPad (10th generation)",
        "iPad14,1": "iPad mini (6th generation)",
        "iPad14,2": "iPad mini (6th generation)",
        "iPad14,3": "iPad Pro (11-inch) (4th generation)",
        "iPad14,4": "iPad Pro (11-inch) (4th generation)",
        "iPad14,5": "iPad Pro (12.9-inch) (6th generation)",
        "iPad14,6": "iPad Pro (12.9-inch) (6th generation)",
        "iPad14,8": "iPad Air 11-inch (M2)",
        "iPad14,9": "iPad Air 11-inch (M2)",
        "iPad14,10": "iPad Air 13-inch (M2)",
        "iPad14,11": "iPad Air 13-inch (M2)",
        "iPad15,3": "iPad Air 11-inch (M3)",
        "iPad15,4": "iPad Air 11-inch (M3)",
        "iPad15,5": "iPad Air 13-inch (M3)",
        "iPad15,6": "iPad Air 13-inch (M3)",
        "iPad15,7": "iPad (A16)",
        "iPad15,8": "iPad (A16)",
        "iPad16,1": "iPad mini (A17 Pro)",
        "iPad16,2": "iPad mini (A17 Pro)",
        "iPad16,3": "iPad Pro 11-inch (M4)",
        "iPad16,4": "iPad Pro 11-inch (M4)",
        "iPad16,5": "iPad Pro 13-inch (M4)",
        "iPad16,6": "iPad Pro 13-inch (M4)",
    ]
}
