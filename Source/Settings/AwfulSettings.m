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

+ (AwfulSettings *)settings
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

struct {
    __unsafe_unretained NSString *Forums;
    __unsafe_unretained NSString *PrivateMessages;
    __unsafe_unretained NSString *Bookmarks;
} AwfulFirstTabs = {
    @"forumslist",
    @"pms",
    @"bookmarks",
};

- (AwfulFirstTab)firstTab
{
    NSString *value = self[AwfulSettingsKeys.firstTab];
    if ([value isEqualToString:AwfulFirstTabs.PrivateMessages]) {
        return AwfulFirstTabPrivateMessages;
    } else if ([value isEqualToString:AwfulFirstTabs.Bookmarks]) {
        return AwfulFirstTabBookmarks;
    } else {
        return AwfulFirstTabForums;
    }
}

- (void)setFirstTab:(AwfulFirstTab)firstTab
{
    NSString *value;
    switch (firstTab) {
        case AwfulFirstTabForums: value = AwfulFirstTabs.Forums; break;
        case AwfulFirstTabBookmarks: value = AwfulFirstTabs.Bookmarks; break;
        case AwfulFirstTabPrivateMessages: value = AwfulFirstTabs.PrivateMessages; break;
        default: return;
    }
    self[AwfulSettingsKeys.firstTab] = value;
}

struct {
    __unsafe_unretained NSString *None;
    __unsafe_unretained NSString *Green;
    __unsafe_unretained NSString *Amber;
    __unsafe_unretained NSString *Macinyos;
    __unsafe_unretained NSString *Winpos95;
} AwfulYOSPOSStyles = {
    @"none",
    @"green",
    @"amber",
    @"macinyos",
    @"winpos95",
};

- (AwfulYOSPOSStyle)yosposStyle
{
    NSString *val = self[AwfulSettingsKeys.yosposStyle];
    if([val isEqualToString:AwfulYOSPOSStyles.None]) {
        return AwfulYOSPOSStyleNone;
    } else if ([val isEqualToString:AwfulYOSPOSStyles.Amber]) {
        return AwfulYOSPOSStyleAmber;
    } else if ([val isEqualToString:AwfulYOSPOSStyles.Green]) {
        return AwfulYOSPOSStyleGreen;
    } else if ([val isEqualToString:AwfulYOSPOSStyles.Macinyos])
    {
        return AwfulYOSPOSStyleMacinyos;
    } else if ([val isEqualToString:AwfulYOSPOSStyles.Winpos95])
    {
        return AwfulYOSPOSStyleWinpos95;
    } else {
        return AwfulYOSPOSStyleGreen;
    }
}

- (void)setYosposStyle:(AwfulYOSPOSStyle)yosposStyle
{
    NSString *val;
    switch (yosposStyle) {
        case AwfulYOSPOSStyleWinpos95:
            val = AwfulYOSPOSStyles.Winpos95;
            break;
        case AwfulYOSPOSStyleMacinyos:
            val = AwfulYOSPOSStyles.Macinyos;
            break;
        case AwfulYOSPOSStyleAmber:
            val = AwfulYOSPOSStyles.Amber;
            break;
        case AwfulYOSPOSStyleGreen:
            val = AwfulYOSPOSStyles.Green;
            break;
        case AwfulYOSPOSStyleNone:
            val = AwfulYOSPOSStyles.None;
            break;
        default:
            return;
    }
    self[AwfulSettingsKeys.yosposStyle] = val;
}

struct {
    __unsafe_unretained NSString *None;
    __unsafe_unretained NSString *Pink;
} AwfulFYADStyles = {
    @"none",
    @"pink",
};

- (AwfulFYADStyle)fyadStyle
{
    NSString *val = self[AwfulSettingsKeys.fyadStyle];
    if ([val isEqual:AwfulFYADStyles.None]) {
        return AwfulFYADStyleNone;
    } else {
        return AwfulFYADStylePink;
    }
}

- (void)setFyadStyle:(AwfulFYADStyle)fyadStyle
{
    switch (fyadStyle) {
        case AwfulFYADStyleNone: self[AwfulSettingsKeys.fyadStyle] = AwfulFYADStyles.None; break;
        case AwfulFYADStylePink: self[AwfulSettingsKeys.fyadStyle] = AwfulFYADStyles.Pink; break;
    }
}

struct {
    __unsafe_unretained NSString *None;
    __unsafe_unretained NSString *Sickly;
} AwfulGasChamberStyles = {
    @"none",
    @"sickly",
};

- (AwfulGasChamberStyle)gasChamberStyle
{
    NSString *val = self[AwfulSettingsKeys.gasChamberStyle];
    if ([val isEqualToString:AwfulGasChamberStyles.None]) {
        return AwfulGasChamberStyleNone;
    } else {
        return AwfulGasChamberStyleSickly;
    }
}

- (void)setGasChamberStyle:(AwfulGasChamberStyle)gasChamberStyle
{
    switch (gasChamberStyle) {
        case AwfulGasChamberStyleNone:
            self[AwfulSettingsKeys.gasChamberStyle] = AwfulGasChamberStyles.None; break;
        case AwfulGasChamberStyleSickly:
            self[AwfulSettingsKeys.gasChamberStyle] = AwfulGasChamberStyles.Sickly; break;
    }
}

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

- (AwfulKeepSidebarOpenWhen)keepSidebarOpen
{
    NSString *value = self[AwfulSettingsKeys.keepSidebarOpen];
    if ([value isEqualToString:AwfulKeepSidebarOpenValues.Never]) {
        return AwfulKeepSidebarOpenNever;
    } else if ([value isEqualToString:AwfulKeepSidebarOpenValues.InLandscape]) {
        return AwfulKeepSidebarOpenInLandscape;
    } else if ([value isEqualToString:AwfulKeepSidebarOpenValues.InPortrait]) {
        return AwfulKeepSidebarOpenInPortrait;
    } else if ([value isEqualToString:AwfulKeepSidebarOpenValues.Always]) {
        return AwfulKeepSidebarOpenAlways;
    } else {
        return AwfulKeepSidebarOpenNever;
    }
}

- (void)setKeepSidebarOpen:(AwfulKeepSidebarOpenWhen)keepSidebarOpen
{
    NSString *value;
    switch (keepSidebarOpen) {
        case AwfulKeepSidebarOpenNever:       value = AwfulKeepSidebarOpenValues.Never;       break;
        case AwfulKeepSidebarOpenInLandscape: value = AwfulKeepSidebarOpenValues.InLandscape; break;
        case AwfulKeepSidebarOpenInPortrait:  value = AwfulKeepSidebarOpenValues.InPortrait;  break;
        case AwfulKeepSidebarOpenAlways:      value = AwfulKeepSidebarOpenValues.Always;      break;
    }
    self[AwfulSettingsKeys.keepSidebarOpen] = value;
}

BOOL_PROPERTY(highlightOwnQuotes, setHighlightOwnQuotes)

BOOL_PROPERTY(highlightOwnMentions, setHighlightOwnMentions)

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

- (NSNumber *)fontSize
{
    return self[AwfulSettingsKeys.fontSize];
}

- (void)setFontSize:(NSNumber *)size
{
    self[AwfulSettingsKeys.fontSize] = size;
}

- (NSString *)lastOfferedPasteboardURL
{
    return self[AwfulSettingsKeys.lastOfferedPasteboardURL];
}

- (void)setLastOfferedPasteboardURL:(NSString *)lastOfferedPasteboardURL
{
    self[AwfulSettingsKeys.lastOfferedPasteboardURL] = lastOfferedPasteboardURL;
}

- (NSString *)lastForcedUserInfoUpdateVersion
{
    return self[AwfulSettingsKeys.lastForcedUserInfoUpdateVersion];
}

- (void)setLastForcedUserInfoUpdateVersion:(NSString *)lastForcedUserInfoUpdateVersion
{
    self[AwfulSettingsKeys.lastForcedUserInfoUpdateVersion] = lastForcedUserInfoUpdateVersion;
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
    // Note nonstandard use of the NSError reference here: it's nilled out if the item could not be
    // found in the keychain.
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

- (id)objectForKeyedSubscript:(id)key
{
    return [[NSUserDefaults standardUserDefaults] objectForKey:key];
}

- (void)setObject:(id)object forKeyedSubscript:(id <NSCopying>)key
{
    NSParameterAssert(key);
    [self setObject:object withoutNotifyingForKey:key];
    NSDictionary *userInfo = @{ AwfulSettingsDidChangeSettingsKey : @[ key ] };
    void (^notify)(void) = ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:AwfulSettingsDidChangeNotification
                                                            object:self
                                                          userInfo:userInfo];
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

NSString * const AwfulSettingsDidChangeSettingsKey = @"settings";

const struct AwfulSettingsKeys AwfulSettingsKeys = {
    .showAvatars = @"show_avatars",
    .showImages = @"show_images",
    .firstTab = @"default_load",
    .highlightOwnQuotes = @"highlight_own_quotes",
    .highlightOwnMentions = @"highlight_own_mentions",
    .confirmNewPosts = @"confirm_before_replying",
	.darkTheme = @"dark_theme",
    .username = @"username",
    .userID = @"userID",
    .canSendPrivateMessages = @"can_send_private_messages",
    .showThreadTags = @"show_thread_tags",
    .yosposStyle = @"yospos_style",
    .fyadStyle = @"fyad_style",
    .gasChamberStyle = @"gas_chamber_style",
    .keepSidebarOpen = @"keep_sidebar_open",
    .favoriteForums = @"favorite_forums",
    .fontSize = @"font_size",
    .lastOfferedPasteboardURL = @"last_offered_pasteboard_URL",
    .lastForcedUserInfoUpdateVersion = @"last_forced_user_info_update_version",
    .customBaseURL = @"custom_base_URL",
    .instapaperUsername = @"instapaper_username",
};
