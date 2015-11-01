//  AwfulSettings.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import Foundation;

@interface AwfulSettings : NSObject

/// The convenient singleton instance.
+ (instancetype)sharedSettings;

/// Registers the default settings in the standard NSUserDefaults.
- (void)registerDefaults;

/// Moves any old settings to their new values, and deletes now-irrelevant settings.
- (void)migrateOldSettings;

/// Returns an array of NSDictionary values each describing a section of settings.
@property (readonly, copy, nonatomic) NSArray *sections;

/// Returns an NSDictionary describing the keyed setting.
- (NSDictionary *)infoForSettingWithKey:(NSString *)key;

@property (assign, nonatomic) BOOL showAvatars;

@property (assign, nonatomic) BOOL showImages;

@property (assign, nonatomic) BOOL forumThreadsSortedByUnread;

@property (assign, nonatomic) BOOL bookmarksSortedByUnread;

@property (assign, nonatomic) BOOL confirmNewPosts;

@property (assign, nonatomic) BOOL darkTheme;

@property (copy, nonatomic) NSString *username;

@property (copy, nonatomic) NSString *userID;

@property (assign, nonatomic) double fontScale;

@property (assign, nonatomic) BOOL canSendPrivateMessages;

@property (assign, nonatomic) BOOL showThreadTags;

@property (copy, nonatomic) NSArray *favoriteForums;

@property (copy, nonatomic) NSString *lastOfferedPasteboardURL;

@property (copy, nonatomic) NSString *customBaseURL;

@property (assign, nonatomic) BOOL hideSidebarInLandscape;

- (NSString *)themeNameForForumID:(NSString *)forumID;

- (void)setThemeName:(NSString *)themeName forForumID:(NSString *)forumID;

@property (copy, nonatomic) NSArray *ubiquitousThemeNames;

@property (assign, nonatomic) BOOL handoffEnabled;

/// Values are one of the strings listed below as AwfulDefaultBrowserXXX.
@property (copy, nonatomic) NSString *defaultBrowser;

@property (assign, nonatomic) BOOL openYouTubeLinksInYouTube;

- (id)objectForKeyedSubscript:(id)key;

- (void)setObject:(id)object forKeyedSubscript:(id <NSCopying>)key;

/// Clears all settings from the standard NSUserDefaults.
- (void)reset;

@end

/// Sent whenever a setting changes. The userInfo dictionary has a value for AwfulSettingsDidChangeSettingKey.
extern NSString * const AwfulSettingsDidChangeNotification;

/// The value is one of the keys in AwfulSettingsKeys indicating which setting changed.
extern NSString * const AwfulSettingsDidChangeSettingKey;

/**
    Possible values for AwfulSettingsDidChangeSettingKey, and keys for subscripting.
 
    N.B. Undocumented here are:
    
        * "theme-X" keys, where X is a forum ID.
        * "forum-expanded-X" keys, where X is a forum ID.
 */
extern const struct AwfulSettingsKeys {
    __unsafe_unretained NSString *showAvatars;
    __unsafe_unretained NSString *showImages;
    __unsafe_unretained NSString *confirmNewPosts;
    __unsafe_unretained NSString *darkTheme;
    __unsafe_unretained NSString *username;
    __unsafe_unretained NSString *userID;
    __unsafe_unretained NSString *forumThreadsSortedByUnread;
    __unsafe_unretained NSString *bookmarksSortedByUnread;
    __unsafe_unretained NSString *canSendPrivateMessages;
    __unsafe_unretained NSString *showThreadTags;
    __unsafe_unretained NSString *favoriteForums;
    __unsafe_unretained NSString *lastOfferedPasteboardURL;
    __unsafe_unretained NSString *customBaseURL;
    __unsafe_unretained NSString *hideSidebarInLandscape;
    __unsafe_unretained NSString *fontScale;
    __unsafe_unretained NSString *ubiquitousThemeNames;
    __unsafe_unretained NSString *handoffEnabled;
    __unsafe_unretained NSString *defaultBrowser;
    __unsafe_unretained NSString *openYouTubeLinksInYouTube;
} AwfulSettingsKeys;

#pragma mark Possible values for the defaultBrowser setting

/// Returns all available, installed default browsers.
extern NSArray * AwfulDefaultBrowsers(void);

/// The built-in Awful Browser.
extern NSString * const AwfulDefaultBrowserAwful;

/// Safari.
extern NSString * const AwfulDefaultBrowserSafari;

/// Chrome. If Chrome is not installed, Safari is returned instead.
extern NSString * const AwfulDefaultBrowserChrome;

/// Returns whether Chrome is installed.
extern BOOL AwfulDefaultBrowserIsChromeInstalled(void);
