//  AwfulSettings.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulSettings.h"
@import UIKit;

@implementation AwfulSettings

+ (AwfulSettings *)sharedSettings
{
    static AwfulSettings *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] initWithResource:@"Settings"];
    });
    return instance;
}

- (id)initWithResource:(NSString *)basename
{
    if ((self = [super init])) {
        NSURL *resourceURL = [[NSBundle mainBundle] URLForResource:basename withExtension:@"plist"];
        NSDictionary *plist = [NSDictionary dictionaryWithContentsOfURL:resourceURL];
        _sections = plist[@"Sections"];
    }
    return self;
}

- (void)registerDefaults
{
    NSArray *listOfSettings = [self.sections valueForKeyPath:@"@unionOfArrays.Settings"];
    NSMutableDictionary *defaults = [NSMutableDictionary new];
    for (NSDictionary *setting in listOfSettings) {
        NSString *key = [setting objectForKey:@"Key"];
        id value = [setting objectForKey:@"Default"];
        if (key && value) {
            [defaults setObject:value forKey:key];
        }
    }
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}

struct {
    __unsafe_unretained NSString *yosposStyle;
    __unsafe_unretained NSString *fyadStyle;
    __unsafe_unretained NSString *gasChamberStyle;
    __unsafe_unretained NSString *keepSidebarOpen;
} OldSettingsKeys = {
    .yosposStyle = @"yospos_style",
    .fyadStyle = @"fyad_style",
    .gasChamberStyle = @"gas_chamber_style",
    .keepSidebarOpen = @"keep_sidebar_open",
};

struct {
    __unsafe_unretained NSString *Never;
    __unsafe_unretained NSString *InLandscape;
    __unsafe_unretained NSString *InPortrait;
    __unsafe_unretained NSString *Always;
} AwfulKeepSidebarOpenValues = {
    @"never",
    @"landscape",
    @"portrait",
    @"always",
};

- (void)migrateOldSettings
{
    NSString *oldYOSPOSStyle = self[OldSettingsKeys.yosposStyle];
    if (oldYOSPOSStyle) {
        NSString *newYOSPOSStyle;
        if ([oldYOSPOSStyle isEqualToString:@"green"]) {
            newYOSPOSStyle = @"YOSPOS";
        } else if ([oldYOSPOSStyle isEqualToString:@"amber"]) {
            newYOSPOSStyle = @"YOSPOS (amber)";
        } else if ([oldYOSPOSStyle isEqualToString:@"macinyos"]) {
            newYOSPOSStyle = @"Macinyos";
        } else if ([oldYOSPOSStyle isEqualToString:@"winpos95"]) {
            newYOSPOSStyle = @"Winpos 95";
        }
        [self setThemeName:newYOSPOSStyle forForumID:@"219"];
        self[OldSettingsKeys.yosposStyle] = nil;
    }
    
    NSString *keepSidebarOpen = self[OldSettingsKeys.keepSidebarOpen];
    if ([keepSidebarOpen isEqualToString:AwfulKeepSidebarOpenValues.Never] || [keepSidebarOpen isEqualToString:AwfulKeepSidebarOpenValues.InPortrait]) {
        self[AwfulSettingsKeys.hideSidebarInLandscape] = @YES;
    }
    self[OldSettingsKeys.keepSidebarOpen] = nil;
    
    // Forums migration to the cloud invalidated the IP option, so we need to revert back to the default hostname.
    self.customBaseURL = nil;
}

@synthesize sections = _sections;

- (NSDictionary *)infoForSettingWithKey:(NSString *)key
{
    for (NSDictionary *section in self.sections) {
        for (NSDictionary *setting in section[@"Settings"]) {
            if ([setting[@"Key"] isEqual:key]) {
                return setting;
            }
        }
    }
    return nil;
}

#define BOOL_PROPERTY(__get, __set) \
- (BOOL)__get \
{ \
    return [self[AwfulSettingsKeys.__get] boolValue]; \
} \
\
- (void)__set:(BOOL)val \
{ \
    self[AwfulSettingsKeys.__get] = @(val); \
}

BOOL_PROPERTY(showAvatars, setShowAvatars)

BOOL_PROPERTY(showImages, setShowImages)

BOOL_PROPERTY(autoplayGIFs, setAutoplayGIFs)

BOOL_PROPERTY(embedTweets, setEmbedTweets)

BOOL_PROPERTY(confirmNewPosts, setConfirmNewPosts)

BOOL_PROPERTY(darkTheme, setDarkTheme)

BOOL_PROPERTY(autoDarkTheme, setAutoDarkTheme)

- (double)autoThemeThreshold {
    return [self[AwfulSettingsKeys.autoThemeThreshold] doubleValue];
}

- (void)setAutoThemeThreshold:(double)autoThemeThreshold {
    self[AwfulSettingsKeys.autoThemeThreshold] = @(autoThemeThreshold);
}

BOOL_PROPERTY(pullForNext, setPullForNext)

struct {
    __unsafe_unretained NSString *currentUser;
} ObsoleteSettingsKeys = {
    @"current_user",
};

- (NSString *)username
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *username = [defaults objectForKey:AwfulSettingsKeys.username];
    if (username) return username;
    NSDictionary *oldUser = [defaults objectForKey:ObsoleteSettingsKeys.currentUser];
    [defaults removeObjectForKey:ObsoleteSettingsKeys.currentUser];
    [self setObject:oldUser[@"username"] withoutNotifyingForKey:AwfulSettingsKeys.username];
    return oldUser[@"username"];
}

- (void)setUsername:(NSString *)username
{
    self[AwfulSettingsKeys.username] = username;
}

- (NSString *)userID
{
    return self[AwfulSettingsKeys.userID];
}

- (void)setUserID:(NSString *)userID
{
    self[AwfulSettingsKeys.userID] = userID;
}

BOOL_PROPERTY(forumThreadsSortedByUnread, setForumThreadsSortedByUnread)

BOOL_PROPERTY(bookmarksSortedByUnread, setBookmarksSortedByUnread)

BOOL_PROPERTY(canSendPrivateMessages, setCanSendPrivateMessages)

BOOL_PROPERTY(showThreadTags, setShowThreadTags)

- (NSArray *)favoriteForums
{
    return self[AwfulSettingsKeys.favoriteForums];
}

- (void)setFavoriteForums:(NSArray *)favoriteForums
{
    self[AwfulSettingsKeys.favoriteForums] = favoriteForums;
}

- (NSString *)lastOfferedPasteboardURL
{
    return self[AwfulSettingsKeys.lastOfferedPasteboardURL];
}

- (void)setLastOfferedPasteboardURL:(NSString *)lastOfferedPasteboardURL
{
    self[AwfulSettingsKeys.lastOfferedPasteboardURL] = lastOfferedPasteboardURL;
}

- (double)fontScale
{
    return [self[AwfulSettingsKeys.fontScale] doubleValue];
}

- (void)setFontScale:(double)fontScale
{
    self[AwfulSettingsKeys.fontScale] = @(fontScale);
}

- (NSString *)customBaseURL
{
    return self[AwfulSettingsKeys.customBaseURL];
}

- (void)setCustomBaseURL:(NSString *)customBaseURL
{
    self[AwfulSettingsKeys.customBaseURL] = customBaseURL;
}

BOOL_PROPERTY(hideSidebarInLandscape, setHideSidebarInLandscape)

- (NSString *)themeNameForForumID:(NSString *)forumID
{
    return self[ThemeSettingsKeyForForumID(forumID)];
}

- (void)setThemeName:(NSString *)themeName forForumID:(NSString *)forumID
{
    NSDictionary *defaults = [[NSUserDefaults standardUserDefaults] volatileDomainForName:NSRegistrationDomain];
    NSString *key = ThemeSettingsKeyForForumID(forumID);
    if (defaults[key] && [defaults[key] isEqual:themeName]) {
        self[key] = nil;
    } else if (!defaults[key] && ThemeNameIsDefaultTheme(themeName)) {
        self[key] = nil;
    } else {
        self[key] = themeName;
    }
}

static inline NSString * ThemeSettingsKeyForForumID(NSString *forumID)
{
    return [@"theme-" stringByAppendingString:forumID];
}

static inline BOOL ThemeNameIsDefaultTheme(NSString *themeName)
{
    return themeName.length == 0 || [themeName isEqualToString:@"default"] || [themeName isEqualToString:@"dark"];
}

- (NSArray *)ubiquitousThemeNames
{
    return self[AwfulSettingsKeys.ubiquitousThemeNames];
}

- (void)setUbiquitousThemeNames:(NSArray *)ubiquitousThemeNames
{
    self[AwfulSettingsKeys.ubiquitousThemeNames] = ubiquitousThemeNames;
}

BOOL_PROPERTY(handoffEnabled, setHandoffEnabled)

BOOL_PROPERTY(clipboardURLEnabled, setClipboardURLEnabled)

- (NSString *)defaultBrowser
{
    NSString *browser = self[AwfulSettingsKeys.defaultBrowser];
    
    if ([browser isEqualToString:AwfulDefaultBrowserChrome] && !AwfulDefaultBrowserIsChromeInstalled()) {
        return AwfulDefaultBrowserSafari;
    }
    
    return browser;
}

- (void)setDefaultBrowser:(NSString *)defaultBrowser
{
    if (defaultBrowser.length > 0) {
        NSAssert([AwfulDefaultBrowsers() containsObject:defaultBrowser], @"trying to set unknown default browser %@", defaultBrowser);
    }
    
    self[AwfulSettingsKeys.defaultBrowser] = defaultBrowser;
}

BOOL_PROPERTY(openYouTubeLinksInYouTube, setOpenYouTubeLinksInYouTube)

BOOL_PROPERTY(openTwitterLinksInTwitter, setOpenTwitterLinksInTwitter)

- (id)objectForKeyedSubscript:(id)key
{
    return [[NSUserDefaults standardUserDefaults] objectForKey:key];
}

- (void)setObject:(id)object forKeyedSubscript:(id <NSCopying>)key
{
    NSParameterAssert(key);
    id old = self[key];
    if (old == object || [old isEqual:object]) return;
    
    [self willChangeValueForKey:(NSString *)key];
    
    [self setObject:object withoutNotifyingForKey:key];
    
    [self didChangeValueForKey:(NSString *)key];
    
    NSDictionary *userInfo = @{AwfulSettingsDidChangeSettingKey : key};
    void (^notify)(void) = ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:AwfulSettingsDidChangeNotification object:self userInfo:userInfo];
    };
    if ([NSThread isMainThread]) {
        notify();
    } else {
        dispatch_async(dispatch_get_main_queue(), notify);
    }
}

- (id)valueForUndefinedKey:(NSString *)key
{
    return self[key];
}

- (void)setValue:(id)value forUndefinedKey:(NSString *)key
{
    self[key] = value;
}

- (void)setObject:(id)object withoutNotifyingForKey:(id)key
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (object) [defaults setObject:object forKey:(NSString *)key];
    else [defaults removeObjectForKey:(NSString *)key];
    [defaults synchronize];
}

- (void)reset
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *empty = @{};
        
    NSString *appDomain = [[NSBundle mainBundle] bundleIdentifier];
    [userDefaults setPersistentDomain:empty forName:appDomain];
    [userDefaults synchronize];
}

@end


NSString * const AwfulSettingsDidChangeNotification = @"com.awfulapp.Awful.SettingsDidChange";

NSString * const AwfulSettingsDidChangeSettingKey = @"setting";

const struct AwfulSettingsKeys AwfulSettingsKeys = {
    .showAvatars = @"show_avatars",
    .showImages = @"show_images",
    .autoplayGIFs = @"autoplay_gifs",
    .embedTweets = @"embed_tweets",
    .forumThreadsSortedByUnread = @"forum_threads_sorted_unread",
    .bookmarksSortedByUnread = @"bookmarks_sorted_unread",
    .confirmNewPosts = @"confirm_before_replying",
    .darkTheme = @"dark_theme",
    .autoDarkTheme = @"auto_dark_theme",
    .autoThemeThreshold = @"auto_theme_threshold",
    .pullForNext = @"pull_for_next",
    .username = @"username",
    .userID = @"userID",
    .canSendPrivateMessages = @"can_send_private_messages",
    .showThreadTags = @"show_thread_tags",
    .favoriteForums = @"favorite_forums",
    .lastOfferedPasteboardURL = @"last_offered_pasteboard_URL",
    .customBaseURL = @"custom_base_URL",
    .hideSidebarInLandscape = @"hide_sidebar_in_landscape",
    .fontScale = @"font_scale",
    .ubiquitousThemeNames = @"ubiquitous_theme_names",
    .handoffEnabled = @"handoff_enabled",
    .clipboardURLEnabled = @"clipboard_url_enabled",
    .defaultBrowser = @"default_browser",
    .openYouTubeLinksInYouTube = @"open_youtube_links_in_youtube",
    .openTwitterLinksInTwitter = @"open_twitter_links_in_twitter",
};

NSArray * AwfulDefaultBrowsers(void)
{
    NSArray *alwaysInstalled = @[AwfulDefaultBrowserAwful, AwfulDefaultBrowserSafari];
    if (AwfulDefaultBrowserIsChromeInstalled()) {
        return [alwaysInstalled arrayByAddingObject:AwfulDefaultBrowserChrome];
    } else {
        return alwaysInstalled;
    }
}

NSString * const AwfulDefaultBrowserAwful = @"Awful";
NSString * const AwfulDefaultBrowserSafari = @"Safari";
NSString * const AwfulDefaultBrowserChrome = @"Chrome";

BOOL AwfulDefaultBrowserIsChromeInstalled(void)
{
    return [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"googlechrome://"]];
}
