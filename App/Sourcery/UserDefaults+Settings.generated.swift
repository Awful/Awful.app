// Generated using Sourcery 0.17.0 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

//  UserDefaults+Settings
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

/*
 KVO-compliant properties for various Awful settings.

 `UserDefaults` instances emit KVO notifications when values change. In order to use these with Swift's awesome `observe(keyPath:…)` methods, we need to:

    * Expose a property on `UserDefaults` for each key we're interested in.
    * Either have that property's name match the key, or add some KVO machinery so changes to the key notify observers of the property. (That machinery is the `automaticallyNotifiesObserversOf…` and `keyPathsForValuesAffecting…` class properties. We turn off automatic notification because we only want notifications when the underlying defaults key changes, and we specify the underlying defaults key as a key path whose value affects the property.)

 To add settings, see `UserDefaults+Settings.swift`. To change what gets generated for each setting, see `UserDefaults+Settings.stencil`.
 */
extension UserDefaults {


    @objc dynamic var automaticallyEnableDarkMode: Bool {
        get { return bool(forKey: SettingsKeys.automaticallyEnableDarkMode) }
        set { set(newValue, forKey: SettingsKeys.automaticallyEnableDarkMode) }
    }

    @objc private class var automaticallyNotifiesObserversOfAutomaticallyEnableDarkMode: Bool { false }

    @objc private class var keyPathsForValuesAffectingAutomaticallyEnableDarkMode: Set<String> { [SettingsKeys.automaticallyEnableDarkMode] }


    @objc dynamic var automaticallyPlayGIFs: Bool {
        get { return bool(forKey: SettingsKeys.automaticallyPlayGIFs) }
        set { set(newValue, forKey: SettingsKeys.automaticallyPlayGIFs) }
    }

    @objc private class var automaticallyNotifiesObserversOfAutomaticallyPlayGIFs: Bool { false }

    @objc private class var keyPathsForValuesAffectingAutomaticallyPlayGIFs: Set<String> { [SettingsKeys.automaticallyPlayGIFs] }


    @objc dynamic var confirmNewPosts: Bool {
        get { return bool(forKey: SettingsKeys.confirmNewPosts) }
        set { set(newValue, forKey: SettingsKeys.confirmNewPosts) }
    }

    @objc private class var automaticallyNotifiesObserversOfConfirmNewPosts: Bool { false }

    @objc private class var keyPathsForValuesAffectingConfirmNewPosts: Set<String> { [SettingsKeys.confirmNewPosts] }


    @objc dynamic var customBaseURLString: String? {
        get { return string(forKey: SettingsKeys.customBaseURLString) }
        set { set(newValue, forKey: SettingsKeys.customBaseURLString) }
    }

    @objc private class var automaticallyNotifiesObserversOfCustomBaseURLString: Bool { false }

    @objc private class var keyPathsForValuesAffectingCustomBaseURLString: Set<String> { [SettingsKeys.customBaseURLString] }


    @objc dynamic var defaultDarkTheme: String {
        get { return string(forKey: SettingsKeys.defaultDarkTheme)! }
        set { set(newValue, forKey: SettingsKeys.defaultDarkTheme) }
    }

    @objc private class var automaticallyNotifiesObserversOfDefaultDarkTheme: Bool { false }

    @objc private class var keyPathsForValuesAffectingDefaultDarkTheme: Set<String> { [SettingsKeys.defaultDarkTheme] }


    @objc dynamic var defaultLightTheme: String {
        get { return string(forKey: SettingsKeys.defaultLightTheme)! }
        set { set(newValue, forKey: SettingsKeys.defaultLightTheme) }
    }

    @objc private class var automaticallyNotifiesObserversOfDefaultLightTheme: Bool { false }

    @objc private class var keyPathsForValuesAffectingDefaultLightTheme: Set<String> { [SettingsKeys.defaultLightTheme] }


    @objc dynamic var embedTweets: Bool {
        get { return bool(forKey: SettingsKeys.embedTweets) }
        set { set(newValue, forKey: SettingsKeys.embedTweets) }
    }

    @objc private class var automaticallyNotifiesObserversOfEmbedTweets: Bool { false }

    @objc private class var keyPathsForValuesAffectingEmbedTweets: Set<String> { [SettingsKeys.embedTweets] }


    @objc dynamic var fontScale: Double {
        get { return double(forKey: SettingsKeys.fontScale) }
        set { set(newValue, forKey: SettingsKeys.fontScale) }
    }

    @objc private class var automaticallyNotifiesObserversOfFontScale: Bool { false }

    @objc private class var keyPathsForValuesAffectingFontScale: Set<String> { [SettingsKeys.fontScale] }


    @objc dynamic var hideSidebarInLandscape: Bool {
        get { return bool(forKey: SettingsKeys.hideSidebarInLandscape) }
        set { set(newValue, forKey: SettingsKeys.hideSidebarInLandscape) }
    }

    @objc private class var automaticallyNotifiesObserversOfHideSidebarInLandscape: Bool { false }

    @objc private class var keyPathsForValuesAffectingHideSidebarInLandscape: Set<String> { [SettingsKeys.hideSidebarInLandscape] }


    @objc dynamic var isDarkModeEnabled: Bool {
        get { return bool(forKey: SettingsKeys.isDarkModeEnabled) }
        set { set(newValue, forKey: SettingsKeys.isDarkModeEnabled) }
    }

    @objc private class var automaticallyNotifiesObserversOfIsDarkModeEnabled: Bool { false }

    @objc private class var keyPathsForValuesAffectingIsDarkModeEnabled: Set<String> { [SettingsKeys.isDarkModeEnabled] }


    @objc dynamic var isHandoffEnabled: Bool {
        get { return bool(forKey: SettingsKeys.isHandoffEnabled) }
        set { set(newValue, forKey: SettingsKeys.isHandoffEnabled) }
    }

    @objc private class var automaticallyNotifiesObserversOfIsHandoffEnabled: Bool { false }

    @objc private class var keyPathsForValuesAffectingIsHandoffEnabled: Set<String> { [SettingsKeys.isHandoffEnabled] }


    @objc dynamic var isPullForNextEnabled: Bool {
        get { return bool(forKey: SettingsKeys.isPullForNextEnabled) }
        set { set(newValue, forKey: SettingsKeys.isPullForNextEnabled) }
    }

    @objc private class var automaticallyNotifiesObserversOfIsPullForNextEnabled: Bool { false }

    @objc private class var keyPathsForValuesAffectingIsPullForNextEnabled: Set<String> { [SettingsKeys.isPullForNextEnabled] }


    @objc dynamic var lastOfferedPasteboardURLString: String? {
        get { return string(forKey: SettingsKeys.lastOfferedPasteboardURLString) }
        set { set(newValue, forKey: SettingsKeys.lastOfferedPasteboardURLString) }
    }

    @objc private class var automaticallyNotifiesObserversOfLastOfferedPasteboardURLString: Bool { false }

    @objc private class var keyPathsForValuesAffectingLastOfferedPasteboardURLString: Set<String> { [SettingsKeys.lastOfferedPasteboardURLString] }


    @objc dynamic var loggedInUserCanSendPrivateMessages: Bool {
        get { return bool(forKey: SettingsKeys.loggedInUserCanSendPrivateMessages) }
        set { set(newValue, forKey: SettingsKeys.loggedInUserCanSendPrivateMessages) }
    }

    @objc private class var automaticallyNotifiesObserversOfLoggedInUserCanSendPrivateMessages: Bool { false }

    @objc private class var keyPathsForValuesAffectingLoggedInUserCanSendPrivateMessages: Set<String> { [SettingsKeys.loggedInUserCanSendPrivateMessages] }


    @objc dynamic var loggedInUserID: String? {
        get { return string(forKey: SettingsKeys.loggedInUserID) }
        set { set(newValue, forKey: SettingsKeys.loggedInUserID) }
    }

    @objc private class var automaticallyNotifiesObserversOfLoggedInUserID: Bool { false }

    @objc private class var keyPathsForValuesAffectingLoggedInUserID: Set<String> { [SettingsKeys.loggedInUserID] }


    @objc dynamic var loggedInUsername: String? {
        get { return string(forKey: SettingsKeys.loggedInUsername) }
        set { set(newValue, forKey: SettingsKeys.loggedInUsername) }
    }

    @objc private class var automaticallyNotifiesObserversOfLoggedInUsername: Bool { false }

    @objc private class var keyPathsForValuesAffectingLoggedInUsername: Set<String> { [SettingsKeys.loggedInUsername] }


    @objc dynamic var openCopiedURLAfterBecomingActive: Bool {
        get { return bool(forKey: SettingsKeys.openCopiedURLAfterBecomingActive) }
        set { set(newValue, forKey: SettingsKeys.openCopiedURLAfterBecomingActive) }
    }

    @objc private class var automaticallyNotifiesObserversOfOpenCopiedURLAfterBecomingActive: Bool { false }

    @objc private class var keyPathsForValuesAffectingOpenCopiedURLAfterBecomingActive: Set<String> { [SettingsKeys.openCopiedURLAfterBecomingActive] }


    @objc dynamic var openTwitterLinksInTwitter: Bool {
        get { return bool(forKey: SettingsKeys.openTwitterLinksInTwitter) }
        set { set(newValue, forKey: SettingsKeys.openTwitterLinksInTwitter) }
    }

    @objc private class var automaticallyNotifiesObserversOfOpenTwitterLinksInTwitter: Bool { false }

    @objc private class var keyPathsForValuesAffectingOpenTwitterLinksInTwitter: Set<String> { [SettingsKeys.openTwitterLinksInTwitter] }


    @objc dynamic var openYouTubeLinksInYouTube: Bool {
        get { return bool(forKey: SettingsKeys.openYouTubeLinksInYouTube) }
        set { set(newValue, forKey: SettingsKeys.openYouTubeLinksInYouTube) }
    }

    @objc private class var automaticallyNotifiesObserversOfOpenYouTubeLinksInYouTube: Bool { false }

    @objc private class var keyPathsForValuesAffectingOpenYouTubeLinksInYouTube: Set<String> { [SettingsKeys.openYouTubeLinksInYouTube] }


    @objc dynamic var postLargeImagesAsThumbnails: Bool {
        get { return bool(forKey: SettingsKeys.postLargeImagesAsThumbnails) }
        set { set(newValue, forKey: SettingsKeys.postLargeImagesAsThumbnails) }
    }

    @objc private class var automaticallyNotifiesObserversOfPostLargeImagesAsThumbnails: Bool { false }

    @objc private class var keyPathsForValuesAffectingPostLargeImagesAsThumbnails: Set<String> { [SettingsKeys.postLargeImagesAsThumbnails] }


    @objc dynamic var rawDefaultBrowser: String? {
        get { return string(forKey: SettingsKeys.rawDefaultBrowser) }
        set { set(newValue, forKey: SettingsKeys.rawDefaultBrowser) }
    }

    @objc private class var automaticallyNotifiesObserversOfRawDefaultBrowser: Bool { false }

    @objc private class var keyPathsForValuesAffectingRawDefaultBrowser: Set<String> { [SettingsKeys.rawDefaultBrowser] }


    @objc dynamic var showAuthorAvatars: Bool {
        get { return bool(forKey: SettingsKeys.showAuthorAvatars) }
        set { set(newValue, forKey: SettingsKeys.showAuthorAvatars) }
    }

    @objc private class var automaticallyNotifiesObserversOfShowAuthorAvatars: Bool { false }

    @objc private class var keyPathsForValuesAffectingShowAuthorAvatars: Set<String> { [SettingsKeys.showAuthorAvatars] }


    @objc dynamic var jumpToPostEndOnDoubleTap: Bool {
        get { return bool(forKey: SettingsKeys.jumpToPostEndOnDoubleTap) }
        set { set(newValue, forKey: SettingsKeys.jumpToPostEndOnDoubleTap) }
    }

    @objc private class var automaticallyNotifiesObserversOfJumpToPostEndOnDoubleTap: Bool { false }

    @objc private class var keyPathsForValuesAffectingJumpToPostEndOnDoubleTap: Set<String> { [SettingsKeys.jumpToPostEndOnDoubleTap] }


    @objc dynamic var enableHaptics: Bool {
        get { return bool(forKey: SettingsKeys.enableHaptics) }
        set { set(newValue, forKey: SettingsKeys.enableHaptics) }
    }

    @objc private class var automaticallyNotifiesObserversOfEnableHaptics: Bool { false }

    @objc private class var keyPathsForValuesAffectingEnableHaptics: Set<String> { [SettingsKeys.enableHaptics] }


    @objc dynamic var enableCustomTitlePostLayout: Bool {
        get { return bool(forKey: SettingsKeys.enableCustomTitlePostLayout) }
        set { set(newValue, forKey: SettingsKeys.enableCustomTitlePostLayout) }
    }

    @objc private class var automaticallyNotifiesObserversOfEnableCustomTitlePostLayout: Bool { false }

    @objc private class var keyPathsForValuesAffectingEnableCustomTitlePostLayout: Set<String> { [SettingsKeys.enableCustomTitlePostLayout] }


    @objc dynamic var enableFrogAndGhost: Bool {
        get { return bool(forKey: SettingsKeys.enableFrogAndGhost) }
        set { set(newValue, forKey: SettingsKeys.enableFrogAndGhost) }
    }

    @objc private class var automaticallyNotifiesObserversOfEnableFrogAndGhost: Bool { false }

    @objc private class var keyPathsForValuesAffectingEnableFrogAndGhost: Set<String> { [SettingsKeys.enableFrogAndGhost] }


    @objc dynamic var showImages: Bool {
        get { return bool(forKey: SettingsKeys.showImages) }
        set { set(newValue, forKey: SettingsKeys.showImages) }
    }

    @objc private class var automaticallyNotifiesObserversOfShowImages: Bool { false }

    @objc private class var keyPathsForValuesAffectingShowImages: Set<String> { [SettingsKeys.showImages] }


    @objc dynamic var showThreadTagsInThreadList: Bool {
        get { return bool(forKey: SettingsKeys.showThreadTagsInThreadList) }
        set { set(newValue, forKey: SettingsKeys.showThreadTagsInThreadList) }
    }

    @objc private class var automaticallyNotifiesObserversOfShowThreadTagsInThreadList: Bool { false }

    @objc private class var keyPathsForValuesAffectingShowThreadTagsInThreadList: Set<String> { [SettingsKeys.showThreadTagsInThreadList] }


    @objc dynamic var showTweaksOnShake: Bool {
        get { return bool(forKey: SettingsKeys.showTweaksOnShake) }
        set { set(newValue, forKey: SettingsKeys.showTweaksOnShake) }
    }

    @objc private class var automaticallyNotifiesObserversOfShowTweaksOnShake: Bool { false }

    @objc private class var keyPathsForValuesAffectingShowTweaksOnShake: Set<String> { [SettingsKeys.showTweaksOnShake] }


    @objc dynamic var showUnreadAnnouncementsBadge: Bool {
        get { return bool(forKey: SettingsKeys.showUnreadAnnouncementsBadge) }
        set { set(newValue, forKey: SettingsKeys.showUnreadAnnouncementsBadge) }
    }

    @objc private class var automaticallyNotifiesObserversOfShowUnreadAnnouncementsBadge: Bool { false }

    @objc private class var keyPathsForValuesAffectingShowUnreadAnnouncementsBadge: Set<String> { [SettingsKeys.showUnreadAnnouncementsBadge] }


    @objc dynamic var sortUnreadBookmarksFirst: Bool {
        get { return bool(forKey: SettingsKeys.sortUnreadBookmarksFirst) }
        set { set(newValue, forKey: SettingsKeys.sortUnreadBookmarksFirst) }
    }

    @objc private class var automaticallyNotifiesObserversOfSortUnreadBookmarksFirst: Bool { false }

    @objc private class var keyPathsForValuesAffectingSortUnreadBookmarksFirst: Set<String> { [SettingsKeys.sortUnreadBookmarksFirst] }


    @objc dynamic var sortUnreadForumThreadsFirst: Bool {
        get { return bool(forKey: SettingsKeys.sortUnreadForumThreadsFirst) }
        set { set(newValue, forKey: SettingsKeys.sortUnreadForumThreadsFirst) }
    }

    @objc private class var automaticallyNotifiesObserversOfSortUnreadForumThreadsFirst: Bool { false }

    @objc private class var keyPathsForValuesAffectingSortUnreadForumThreadsFirst: Set<String> { [SettingsKeys.sortUnreadForumThreadsFirst] }

}
