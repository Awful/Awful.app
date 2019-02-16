// Generated using Sourcery 0.15.0 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

//  UserDefaults+Settings
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

/*
 KVO-compliant properties for various Awful settings.

 `UserDefaults` instances emit KVO notifications when values change. In order to use these with Swift's awesome `observe(keyPath:…)` methods, we need to:

    * Expose a property on `UserDefaults` for each key we're interested in.
    * Either have that property's name match the key, or add some KVO machinery so changes to the key notify observers of the property. (That machinery is the `keyPathsForValuesAffecting…` class properties.)

 To add settings, see `UserDefaults+Settings.swift`. To change what gets generated for each setting, see `UserDefaults+Settings.stencil`.
 */
extension UserDefaults {


    @objc dynamic var automaticallyEnableDarkMode: Bool {
        get { return bool(forKey: SettingsKeys.automaticallyEnableDarkMode) }
        set { set(newValue, forKey: SettingsKeys.automaticallyEnableDarkMode) }
    }

    @objc private class var keyPathsForValuesAffectingAutomaticallyEnableDarkMode: Set<String> {
        return [SettingsKeys.automaticallyEnableDarkMode]
    }


    @objc dynamic var automaticallyPlayGIFs: Bool {
        get { return bool(forKey: SettingsKeys.automaticallyPlayGIFs) }
        set { set(newValue, forKey: SettingsKeys.automaticallyPlayGIFs) }
    }

    @objc private class var keyPathsForValuesAffectingAutomaticallyPlayGIFs: Set<String> {
        return [SettingsKeys.automaticallyPlayGIFs]
    }


    @objc dynamic var automaticDarkModeBrightnessThresholdPercent: Double {
        get { return double(forKey: SettingsKeys.automaticDarkModeBrightnessThresholdPercent) }
        set { set(newValue, forKey: SettingsKeys.automaticDarkModeBrightnessThresholdPercent) }
    }

    @objc private class var keyPathsForValuesAffectingAutomaticDarkModeBrightnessThresholdPercent: Set<String> {
        return [SettingsKeys.automaticDarkModeBrightnessThresholdPercent]
    }


    @objc dynamic var confirmNewPosts: Bool {
        get { return bool(forKey: SettingsKeys.confirmNewPosts) }
        set { set(newValue, forKey: SettingsKeys.confirmNewPosts) }
    }

    @objc private class var keyPathsForValuesAffectingConfirmNewPosts: Set<String> {
        return [SettingsKeys.confirmNewPosts]
    }


    @objc dynamic var customBaseURLString: String? {
        get { return string(forKey: SettingsKeys.customBaseURLString) }
        set { set(newValue, forKey: SettingsKeys.customBaseURLString) }
    }

    @objc private class var keyPathsForValuesAffectingCustomBaseURLString: Set<String> {
        return [SettingsKeys.customBaseURLString]
    }


    @objc dynamic var embedTweets: Bool {
        get { return bool(forKey: SettingsKeys.embedTweets) }
        set { set(newValue, forKey: SettingsKeys.embedTweets) }
    }

    @objc private class var keyPathsForValuesAffectingEmbedTweets: Set<String> {
        return [SettingsKeys.embedTweets]
    }


    @objc dynamic var fontScale: Double {
        get { return double(forKey: SettingsKeys.fontScale) }
        set { set(newValue, forKey: SettingsKeys.fontScale) }
    }

    @objc private class var keyPathsForValuesAffectingFontScale: Set<String> {
        return [SettingsKeys.fontScale]
    }


    @objc dynamic var hideSidebarInLandscape: Bool {
        get { return bool(forKey: SettingsKeys.hideSidebarInLandscape) }
        set { set(newValue, forKey: SettingsKeys.hideSidebarInLandscape) }
    }

    @objc private class var keyPathsForValuesAffectingHideSidebarInLandscape: Set<String> {
        return [SettingsKeys.hideSidebarInLandscape]
    }


    @objc dynamic var isAlternateThemeEnabled: Bool {
        get { return bool(forKey: SettingsKeys.isAlternateThemeEnabled) }
        set { set(newValue, forKey: SettingsKeys.isAlternateThemeEnabled) }
    }

    @objc private class var keyPathsForValuesAffectingIsAlternateThemeEnabled: Set<String> {
        return [SettingsKeys.isAlternateThemeEnabled]
    }


    @objc dynamic var isDarkModeEnabled: Bool {
        get { return bool(forKey: SettingsKeys.isDarkModeEnabled) }
        set { set(newValue, forKey: SettingsKeys.isDarkModeEnabled) }
    }

    @objc private class var keyPathsForValuesAffectingIsDarkModeEnabled: Set<String> {
        return [SettingsKeys.isDarkModeEnabled]
    }


    @objc dynamic var isHandoffEnabled: Bool {
        get { return bool(forKey: SettingsKeys.isHandoffEnabled) }
        set { set(newValue, forKey: SettingsKeys.isHandoffEnabled) }
    }

    @objc private class var keyPathsForValuesAffectingIsHandoffEnabled: Set<String> {
        return [SettingsKeys.isHandoffEnabled]
    }


    @objc dynamic var isPullForNextEnabled: Bool {
        get { return bool(forKey: SettingsKeys.isPullForNextEnabled) }
        set { set(newValue, forKey: SettingsKeys.isPullForNextEnabled) }
    }

    @objc private class var keyPathsForValuesAffectingIsPullForNextEnabled: Set<String> {
        return [SettingsKeys.isPullForNextEnabled]
    }


    @objc dynamic var lastOfferedPasteboardURLString: String? {
        get { return string(forKey: SettingsKeys.lastOfferedPasteboardURLString) }
        set { set(newValue, forKey: SettingsKeys.lastOfferedPasteboardURLString) }
    }

    @objc private class var keyPathsForValuesAffectingLastOfferedPasteboardURLString: Set<String> {
        return [SettingsKeys.lastOfferedPasteboardURLString]
    }


    @objc dynamic var loggedInUserCanSendPrivateMessages: Bool {
        get { return bool(forKey: SettingsKeys.loggedInUserCanSendPrivateMessages) }
        set { set(newValue, forKey: SettingsKeys.loggedInUserCanSendPrivateMessages) }
    }

    @objc private class var keyPathsForValuesAffectingLoggedInUserCanSendPrivateMessages: Set<String> {
        return [SettingsKeys.loggedInUserCanSendPrivateMessages]
    }


    @objc dynamic var loggedInUserID: String? {
        get { return string(forKey: SettingsKeys.loggedInUserID) }
        set { set(newValue, forKey: SettingsKeys.loggedInUserID) }
    }

    @objc private class var keyPathsForValuesAffectingLoggedInUserID: Set<String> {
        return [SettingsKeys.loggedInUserID]
    }


    @objc dynamic var loggedInUsername: String? {
        get { return string(forKey: SettingsKeys.loggedInUsername) }
        set { set(newValue, forKey: SettingsKeys.loggedInUsername) }
    }

    @objc private class var keyPathsForValuesAffectingLoggedInUsername: Set<String> {
        return [SettingsKeys.loggedInUsername]
    }


    @objc dynamic var openCopiedURLAfterBecomingActive: Bool {
        get { return bool(forKey: SettingsKeys.openCopiedURLAfterBecomingActive) }
        set { set(newValue, forKey: SettingsKeys.openCopiedURLAfterBecomingActive) }
    }

    @objc private class var keyPathsForValuesAffectingOpenCopiedURLAfterBecomingActive: Set<String> {
        return [SettingsKeys.openCopiedURLAfterBecomingActive]
    }


    @objc dynamic var openTwitterLinksInTwitter: Bool {
        get { return bool(forKey: SettingsKeys.openTwitterLinksInTwitter) }
        set { set(newValue, forKey: SettingsKeys.openTwitterLinksInTwitter) }
    }

    @objc private class var keyPathsForValuesAffectingOpenTwitterLinksInTwitter: Set<String> {
        return [SettingsKeys.openTwitterLinksInTwitter]
    }


    @objc dynamic var openYouTubeLinksInYouTube: Bool {
        get { return bool(forKey: SettingsKeys.openYouTubeLinksInYouTube) }
        set { set(newValue, forKey: SettingsKeys.openYouTubeLinksInYouTube) }
    }

    @objc private class var keyPathsForValuesAffectingOpenYouTubeLinksInYouTube: Set<String> {
        return [SettingsKeys.openYouTubeLinksInYouTube]
    }


    @objc dynamic var postLargeImagesAsThumbnails: Bool {
        get { return bool(forKey: SettingsKeys.postLargeImagesAsThumbnails) }
        set { set(newValue, forKey: SettingsKeys.postLargeImagesAsThumbnails) }
    }

    @objc private class var keyPathsForValuesAffectingPostLargeImagesAsThumbnails: Set<String> {
        return [SettingsKeys.postLargeImagesAsThumbnails]
    }


    @objc dynamic var rawDefaultBrowser: String? {
        get { return string(forKey: SettingsKeys.rawDefaultBrowser) }
        set { set(newValue, forKey: SettingsKeys.rawDefaultBrowser) }
    }

    @objc private class var keyPathsForValuesAffectingRawDefaultBrowser: Set<String> {
        return [SettingsKeys.rawDefaultBrowser]
    }


    @objc dynamic var showAuthorAvatars: Bool {
        get { return bool(forKey: SettingsKeys.showAuthorAvatars) }
        set { set(newValue, forKey: SettingsKeys.showAuthorAvatars) }
    }

    @objc private class var keyPathsForValuesAffectingShowAuthorAvatars: Set<String> {
        return [SettingsKeys.showAuthorAvatars]
    }


    @objc dynamic var showImages: Bool {
        get { return bool(forKey: SettingsKeys.showImages) }
        set { set(newValue, forKey: SettingsKeys.showImages) }
    }

    @objc private class var keyPathsForValuesAffectingShowImages: Set<String> {
        return [SettingsKeys.showImages]
    }


    @objc dynamic var showThreadTagsInThreadList: Bool {
        get { return bool(forKey: SettingsKeys.showThreadTagsInThreadList) }
        set { set(newValue, forKey: SettingsKeys.showThreadTagsInThreadList) }
    }

    @objc private class var keyPathsForValuesAffectingShowThreadTagsInThreadList: Set<String> {
        return [SettingsKeys.showThreadTagsInThreadList]
    }


    @objc dynamic var showTweaksOnShake: Bool {
        get { return bool(forKey: SettingsKeys.showTweaksOnShake) }
        set { set(newValue, forKey: SettingsKeys.showTweaksOnShake) }
    }

    @objc private class var keyPathsForValuesAffectingShowTweaksOnShake: Set<String> {
        return [SettingsKeys.showTweaksOnShake]
    }


    @objc dynamic var showUnreadAnnouncementsBadge: Bool {
        get { return bool(forKey: SettingsKeys.showUnreadAnnouncementsBadge) }
        set { set(newValue, forKey: SettingsKeys.showUnreadAnnouncementsBadge) }
    }

    @objc private class var keyPathsForValuesAffectingShowUnreadAnnouncementsBadge: Set<String> {
        return [SettingsKeys.showUnreadAnnouncementsBadge]
    }


    @objc dynamic var sortUnreadBookmarksFirst: Bool {
        get { return bool(forKey: SettingsKeys.sortUnreadBookmarksFirst) }
        set { set(newValue, forKey: SettingsKeys.sortUnreadBookmarksFirst) }
    }

    @objc private class var keyPathsForValuesAffectingSortUnreadBookmarksFirst: Set<String> {
        return [SettingsKeys.sortUnreadBookmarksFirst]
    }


    @objc dynamic var sortUnreadForumThreadsFirst: Bool {
        get { return bool(forKey: SettingsKeys.sortUnreadForumThreadsFirst) }
        set { set(newValue, forKey: SettingsKeys.sortUnreadForumThreadsFirst) }
    }

    @objc private class var keyPathsForValuesAffectingSortUnreadForumThreadsFirst: Set<String> {
        return [SettingsKeys.sortUnreadForumThreadsFirst]
    }

}
