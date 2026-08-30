//  Settings.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulExtensions
import Foil
import Foundation
import SystemCapabilities

/**
 A namespace for user defaults keys and default values. Avoids typos and supports registering defaults.

 See `AppStorage` and `UserDefaults` extensions for conveniences.
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

    /// Remove known tracking query parameters (utm_*, fbclid, YouTube's si, etc.) from URLs pasted into the composer.
    public static let cleanPastedURLs = Setting(key: "clean_pasted_urls", default: true)

    /// Check the general pasteboard for a Forums URL whenever we enter the foreground. iOS shows an alert requesting permission from the user whenever we attempt to check the pasteboard, so we default to off to be less annoying.
    public static let clipboardURLEnabled = Setting(key: "clipboard_url_enabled", default: false)

    /// Show a post preview before submitting a reply to a thread.
    public static let confirmBeforeReplying = Setting(key: "confirm_before_replying", default: true)

    /// Render using dark mode. See also: `autoDarkTheme`.
    public static let darkMode = Setting(key: "dark_theme", default: false)

    /// Which app to use for opening URLs.
    public static let defaultBrowser = Setting(key: "default_browser", default: DefaultBrowser.default)

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

    /// Render the pre-iOS-26 opaque themed bars instead of iOS 26's Liquid Glass chrome. iOS 26+ only.
    public static let disableLiquidGlass = Setting(key: "disable_liquid_glass", default: false)

    /// Turn each Bluesky post link in a Forms post into an embedded Bluesky post.
    public static let embedBlueskyPosts = Setting(key: "embed_bluesky_posts", default: true)

    /// Turn each link to a tweet in a post into an embedded tweet.
    public static let embedTweets = Setting(key: "embed_tweets", default: true)

    /// When `false`, leave video URLs as plain links instead of embedding YouTube, Vimeo, Imgur, etc. video players in posts.
    public static let embedVideos = Setting(key: "embed_videos", default: true)

    /// Show custom titles for authors in the posts view (when it's wide enough).
    public static let enableCustomTitlePostLayout = Setting(key: "enable_custom_title_post_layout", default: false)

    /// Make the device vibrate when certain things happen.
    public static let enableHaptics = Setting(key: "enable_haptics", default: false)

    /// Automatically fetch and append the next page when scrolling near the bottom of the Leper's Colony. Hides the paging toolbar while enabled.
    public static let endlessScrollLepers = Setting(key: "endless_scroll_lepers", default: false)

    /// Automatically fetch and append the next page of posts when scrolling near the bottom of a thread. Hides the paging controls while enabled.
    public static let endlessScrollPosts = Setting(key: "endless_scroll_posts", default: false)

    /// Present the image viewer full-screen instead of as a sheet.
    public static let imageViewerFullScreen = Setting(key: "image_viewer_full_screen", default: false)

    /// Mode for Imgur image uploads (Off, Anonymous, or with Account)
    public static let imgurUploadMode = Setting(key: "imgur_upload_mode", default: ImgurUploadMode.default)

    /// Enable immersive mode: hides navigation and toolbar when scrolling, reveals when reaching bottom or scrolling up.
    public static let immersiveModeEnabled = Setting(key: "immersive_mode_enabled", default: false)

    /// What percentage to multiply the default post font size by. Stored as percentage points, i.e. default is `100` aka "100% size" aka the default.
    public static let fontScale = Setting(key: "font_scale", default: 100.0)

    /// Put threads with unread posts at the top of forums.
    public static let forumThreadsSortedUnread = Setting(key: "forum_threads_sorted_unread", default: false)

    /// Show the frog and ghost animations.
    public static let frogAndGhostEnabled = Setting(key: "frog_and_ghost_enabled", default: true)

    /// Offer to hand off the current thread page to other devices.
    public static let handoffEnabled = Setting(key: "handoff_enabled", default: false)

    /// Whether the logged-in user owns the Archives upgrade (access to old posts/threads).
    public static let hasArchives = Setting(key: "has_archives_upgrade", default: false)

    /// Whether the logged-in user owns the No-Ads upgrade (removes site advertisements).
    public static let hasNoAds = Setting(key: "has_no_ads_upgrade", default: false)

    /// Whether the logged-in user owns the Platinum upgrade (grants private messaging, search, and image uploads).
    public static let hasPlatinum = Setting(key: "has_platinum_upgrade", default: false)

    /// Mark post header (username, regdate, role labels) and post date as `aria-hidden` so iOS Spoken Content / VoiceOver skip them and read post bodies more directly.
    public static let hidePostMetadataForReader = Setting(key: "hide_post_metadata_for_reader", default: false)

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

    /// On launch, reopen the thread the user was last reading (restoring its page and scroll position). When `false`, state restoration returns to the last-used tab without reopening the thread.
    public static let restoreLastThreadOnLaunch = Setting(key: "restore_last_thread_on_launch", default: true)

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
    public static let themeYOSPOS = Setting<BuiltInTheme>(key: "theme-219", default: .yosposGreen)

    /// Scroll the posts page by tilting the device toward or away from you.
    public static let tiltScrollEnabled = Setting(key: "tilt_scroll_enabled", default: false)

    /// Reverse the direction the posts page scrolls when tilting the device.
    public static let tiltScrollInverted = Setting(key: "tilt_scroll_inverted", default: false)

    /// Tilt-to-scroll sensitivity, normalized `0...1`. Scales the maximum scroll speed.
    public static let tiltScrollSensitivity = Setting(key: "tilt_scroll_sensitivity", default: 0.5)

    /// The logged-in user's ID. This really shouldn't be a setting :/
    public static let userID = Setting<String?>(key: "userID")

    /// The logged-in user's username. This really shouldn't be a setting :/
    public static let username = Setting<String?>(key: "username")

    /// Use the new SwiftUI smilie picker with search functionality.
    public static let useNewSmiliePicker = Setting(key: "use_new_smilie_picker", default: true)
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
    case macinyos = "Macinyos"
    case oledDark = "oledDark"
    case spankykongDark = "spankykongDark"
    case spankykongLight = "spankykongLight"
    case winpos95 = "Winpos 95"
    case yosposAmber = "YOSPOS (amber)"
    case yosposGreen = "YOSPOS"
}

/// The upload mode for Imgur images.
public enum ImgurUploadMode: String, CaseIterable, UserDefaultsSerializable {
    // These raw values are persisted in user defaults, so don't change them willy nilly.
    case off = "Off"
    case anonymous = "Anonymous"
    case account = "Imgur Account"
    
    static var `default`: Self { .off }
}

/// The default browser set by the user via `UserDefaults` and `Settings.defaultBrowser`.
public enum DefaultBrowser: String, CaseIterable {
    // These raw values are persisted in user defaults, so don't change them willy nilly.
    case awful = "Awful"
    case defaultiOSBrowser = "Default iOS Browser"
    case brave = "Brave"
    case chrome = "Chrome"
    case edge = "Edge"
    case firefox = "Firefox"

    static var `default`: Self { .awful }

    /// Passing the returned URL to `UIApplication.canOpenURL(_:)` indicates whether the browser is available. When the returned URL is `nil`, it's always available.
    public var checkCanOpenURL: URL? {
        switch self {
        case .awful, .defaultiOSBrowser: nil
        case .brave: URL(string: "brave://")!
        case .chrome: URL(string: "googlechrome://")!
        case .edge: URL(string: "microsoft-edge-http://")!
        case .firefox: URL(string: "firefox://")!
        }
    }
}

extension DefaultBrowser: UserDefaultsSerializable {
    public init(storedValue: String) {
        // Handle browsers that have disappeared from the list by falling back to the default default browser.
        self = Self.init(rawValue: storedValue) ?? .default
    }
}
