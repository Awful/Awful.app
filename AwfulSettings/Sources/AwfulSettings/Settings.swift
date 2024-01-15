//  Settings.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulExtensions
import Foil
import Foundation
import SystemCapabilities

/**
 A namespace for user defaults keys and default values. Avoids typos and supports registering defaults.

 See `AppStorage` and `UserDefaults` extensions in the `AwfulSettingsUI` module for conveniences.
 */
public enum Settings {

    /// The name of the alternative app icon to use.
    public static let appIconName = Setting<String?>(key: "app_icon_name")

    /// Follow the operating system's dark mode setting.
    public static let autoDarkTheme = Setting(key: "auto_dark_theme", default: true)

    /// Use `[timg]` when embedding a sufficiently large image.
    public static let automaticTimg = Setting(key: "automatic_timg", default: true)

    /// Play GIFs in posts by default. When `false`, show the first frame overlaid with a button that starts GIF playback on tap.
    public static let autoplayGIFs = Setting(key: "autoplay_gifs", default: false)

    /// Put threads with unread posts at the top of the bookmarks list.
    public static let bookmarksSortedUnread = Setting(key: "bookmarks_sorted_unread", default: false)

    /// Whether the logged-in user can send private messages. This really shouldn't be a setting :/
    public static let canSendPrivateMessages = Setting(key: "can_send_private_messages", default: false)

    /// Check the general pasteboard for a Forums URL whenever we enter the foreground. As of iOS 14 this shows an alert requesting permission from the user, so we default to off to be less annoying.
    public static let clipboardURLEnabled = Setting(key: "clipboard_url_enabled", default: false)

    /// Show a post preview before submitting a reply to a thread.
    public static let confirmBeforeReplying = Setting(key: "confirm_before_replying", default: true)

    /// The base URL for all Forums requests.
    public static let customBaseURL = Setting(key: "custom_base_URL", default: URL(string: "https://forums.somethingawful.com/")!)

    /// Render using dark mode. See also: `autoDarkTheme`.
    public static let darkMode = Setting(key: "dark_theme", default: false)

    /// Which app to use for opening URLs.
    public static let defaultBrowser = Setting(key: "default_browser", default: DefaultBrowser.awful)

    /// The theme to use by default when dark mode is on.
    public static let defaultDarkThemeName = Setting(
        key: "default_dark_theme_name",
        default: SystemCapabilities.oled ? BuiltInTheme.oledDark : BuiltInTheme.dark
    )

    /// The theme to use by default when dark mode is off.
    public static let defaultLightThemeName = Setting<BuiltInTheme>(
        key: "default_light_theme_name",
        default: SystemCapabilities.oled ? .brightLight : .default
    )

    /// Turn each link to a tweet in a post into an embedded tweet.
    public static let embedTweets = Setting(key: "embed_tweets", default: false)

    /// Show custom titles for authors in the posts view (when it's wide enough).
    public static let enableCustomTitlePostLayout = Setting(key: "enable_custom_title_post_layout", default: false)

    /// Make the device vibrate when certain things happen.
    public static let enableHaptics = Setting(key: "enable_haptics", default: false)

    /// What percentage to multiply the default post font size by. Stored as percentage points, i.e. default is `100` aka "100% size" aka the default.
    public static let fontScale = Setting(key: "font_scale", default: 100.0)

    /// Put threads with unread posts at the top of forums.
    public static let forumThreadsSortedUnread = Setting(key: "forum_threads_sorted_unread", default: false)

    /// Show the frog and ghost animations.
    public static let frogAndGhostEnabled = Setting(key: "frog_and_ghost_enabled", default: true)

    /// Offer to hand off the current thread page to other devices.
    public static let handoffEnabled = Setting(key: "handoff_enabled", default: false)

    /// Hide the sidebar in landscape orientation (assuming the display is wide enough to show the sidebar at all).
    public static let hideSidebarInLandscape = Setting(key: "hide_sidebar_in_landscape", default: false)

    /// Double-tapping a post scrolls to the end of that post.
    public static let jumpToPostEndOnDoubleTap = Setting(key: "jump_to_post_end_on_double_tap", default: false)

    /// The URL string we most recently set on the general pasteboard.
    public static let lastOfferedPasteboardURLString = Setting<String?>(key: "last_offered_pasteboard_URL")

    /// When `false`, replace each embedded image with a link in posts.
    public static let loadImages = Setting(key: "show_images", default: true)

    /// Send links to tweets to the Twitter app (if installed).
    public static let openTwitterLinksInTwitter = Setting(key: "open_twitter_links_in_twitter", default: true)

    /// Send YouTube video links to the YouTube app (if installed).
    public static let openYouTubeLinksInYouTube = Setting(key: "open_youtube_links_in_youtube", default: true)

    /// Pull up from the bottom of a page of posts to go to the next page.
    public static let pullForNext = Setting(key: "pull_for_next", default: true)

    /// Show avatars for authors in the posts view.
    public static let showAvatars = Setting(key: "show_avatars", default: true)

    /// Show thread tags in thread lists.
    public static let showThreadTags = Setting(key: "show_thread_tags", default: true)

    /// Badge the Forums tab whenever there's an unread announcement.
    public static let showUnreadAnnouncementsBadge = Setting(key: "show_unread_announcements_badge", default: true)

    /// The default theme for threads in BYOB.
    public static let themeBYOB = Setting<BuiltInTheme>(key: "theme-268", default: .byob)

    /// The default theme for threads in FYAD.
    public static let themeFYAD = Setting<BuiltInTheme>(key: "theme-26", default: .fyad)

    /// The default theme for threads in the Gas Chamber.
    public static let themeGasChamber = Setting<BuiltInTheme>(key: "theme-25", default: .gasChamber)

    /// The default theme for threads in YOSPOS.
    public static let themeYOSPOS = Setting<BuiltInTheme>(key: "theme-219", default: .yospos)

    /// The logged-in user's ID. This really shouldn't be a setting :/
    public static let userID = Setting<String?>(key: "userID")

    /// The logged-in user's username. This really shouldn't be a setting :/
    public static let username = Setting<String?>(key: "username")
}

/// A theme included with Awful.
public enum BuiltInTheme: String, UserDefaultsSerializable {
    // These raw values are persisted in user defaults, so don't change them willy nilly.
    case alternateDark = "alternateDark"
    case alternateDefault = "alternateDefault"
    case brightLight = "brightLight"
    case byob = "BYOB"
    case dark = "dark"
    case `default` = "default"
    case fyad = "FYAD"
    case gasChamber = "Gas Chamber"
    case oledDark = "oledDark"
    case yospos = "YOSPOS"
}

/// The default browser set by the user via `UserDefaults` and `Settings.defaultBrowser`.
public enum DefaultBrowser: String, CaseIterable, UserDefaultsSerializable {
    // These raw values are persisted in user defaults, so don't change them willy nilly.
    case awful = "Awful"
    case defaultiOSBrowser = "Default iOS Browser"
    case brave = "Brave"
    case chrome = "Chrome"
    case edge = "Edge"
    case firefox = "Firefox"

    /// Passing the returned URL to `UIApplication.canOpenURL(_:)` indicates whether the browser is available. When the returned URL is `nil`, it's always available.
    public var checkCanOpenURL: URL? {
        switch self {
        case .awful, .defaultiOSBrowser: nil
        case .brave: URL("brave://")
        case .chrome: URL("googlechrome://")
        case .edge: URL("microsoft-edge-http://")
        case .firefox: URL("firefox://")
        }
    }
}
