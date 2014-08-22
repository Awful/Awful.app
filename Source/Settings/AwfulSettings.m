//  AwfulSettings.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulSettings.h"
#import <PocketAPI/PocketAPI.h>
#import "SFHFKeychainUtils.h"

@interface AwfulSettings ()

@property (strong) NSArray *sections;

@end

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
    self = [super init];
    if (self)
    {
        NSURL *url = [[NSBundle mainBundle] URLForResource:basename withExtension:@"plist"];
        NSDictionary *plist = [NSDictionary dictionaryWithContentsOfURL:url];
        self.sections = [plist objectForKey:@"Sections"];
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

BOOL_PROPERTY(confirmNewPosts, setConfirmNewPosts)

BOOL_PROPERTY(darkTheme, setDarkTheme)

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

- (NSString *)pocketUsername
{
    if ([[PocketAPI sharedAPI] isLoggedIn]) {
        return [[PocketAPI sharedAPI] username];
    } else {
        return @"[Not logged in]";
    }
}

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

- (NSString *)instapaperUsername
{
    return self[AwfulSettingsKeys.instapaperUsername];
}

- (void)setInstapaperUsername:(NSString *)instapaperUsername
{
    self[AwfulSettingsKeys.instapaperUsername] = instapaperUsername;
}

static NSString * const InstapaperServiceName = @"InstapaperAPI";
static NSString * const InstapaperUsernameKey = @"username";

- (NSString *)instapaperPassword
{
    // Note nonstandard use of the NSError reference here: it's nilled out if the item could not be found in the keychain.
    NSError *error;
    NSString *password = [SFHFKeychainUtils getPasswordForUsername:InstapaperUsernameKey
                                                    andServiceName:InstapaperServiceName
                                                             error:&error];
    if (error) {
        NSLog(@"error retrieving Instapaper API password from keychain: %@", error);
    }
    return password;
}

- (void)setInstapaperPassword:(NSString *)instapaperPassword
{
    BOOL ok;
    NSError *error;
    if (instapaperPassword) {
        ok = [SFHFKeychainUtils storeUsername:InstapaperUsernameKey
                                  andPassword:instapaperPassword
                               forServiceName:InstapaperServiceName
                               updateExisting:YES
                                        error:&error];
    } else {
        ok = [SFHFKeychainUtils deleteItemForUsername:InstapaperUsernameKey
                                       andServiceName:InstapaperServiceName
                                                error:&error];
        if (!ok && error.code == errSecItemNotFound) {
            ok = YES;
        }
    }
    if (!ok) {
        NSLog(@"error %@ Instapaper API password: %@",
              instapaperPassword ? @"setting" : @"clearing", error);
    }
}

BOOL_PROPERTY(hideSidebarInLandscape, setHideSidebarInLandscape)

- (BOOL)childrenExpandedForForumWithID:(NSString *)forumID
{
	return [self[ExpandedSettingsKeyForForumID(forumID)] boolValue];
}

- (void)setChildrenExpanded:(BOOL)shouldHide forForumWithID:(NSString *)forumID
{
	self[ExpandedSettingsKeyForForumID(forumID)] = @(shouldHide);
}

static inline NSString * ExpandedSettingsKeyForForumID(NSString *forumID)
{
    return [@"forum-expanded-" stringByAppendingString:forumID];
}

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

- (id)objectForKeyedSubscript:(id)key
{
    return [[NSUserDefaults standardUserDefaults] objectForKey:key];
}

- (void)setObject:(id)object forKeyedSubscript:(id <NSCopying>)key
{
    NSParameterAssert(key);
    id old = self[key];
    if (old == object || [old isEqual:object]) return;
    [self setObject:object withoutNotifyingForKey:key];
    NSDictionary *userInfo = @{ AwfulSettingsDidChangeSettingKey : key };
    void (^notify)(void) = ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:AwfulSettingsDidChangeNotification object:self userInfo:userInfo];
    };
    if ([NSThread isMainThread]) {
        notify();
    } else {
        dispatch_async(dispatch_get_main_queue(), notify);
    }
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
    
    // Keychain.
    self.instapaperPassword = nil;
}

@end


NSString * const AwfulSettingsDidChangeNotification = @"com.awfulapp.Awful.SettingsDidChange";

NSString * const AwfulSettingsDidChangeSettingKey = @"setting";

const struct AwfulSettingsKeys AwfulSettingsKeys = {
    .showAvatars = @"show_avatars",
    .showImages = @"show_images",
	.bookmarksSortedByUnread = @"bookmarks_sorted_unread",
    .confirmNewPosts = @"confirm_before_replying",
	.darkTheme = @"dark_theme",
    .username = @"username",
    .userID = @"userID",
    .canSendPrivateMessages = @"can_send_private_messages",
    .showThreadTags = @"show_thread_tags",
    .favoriteForums = @"favorite_forums",
    .lastOfferedPasteboardURL = @"last_offered_pasteboard_URL",
    .customBaseURL = @"custom_base_URL",
    .instapaperUsername = @"instapaper_username",
    .hideSidebarInLandscape = @"hide_sidebar_in_landscape",
    .fontScale = @"font_scale",
    .ubiquitousThemeNames = @"ubiquitous_theme_names",
};
