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

struct {
    __unsafe_unretained NSString *yosposStyle;
    __unsafe_unretained NSString *fyadStyle;
    __unsafe_unretained NSString *gasChamberStyle;
} OldSettingsKeys = {
    .yosposStyle = @"yospos_style",
    .fyadStyle = @"fyad_style",
    .gasChamberStyle = @"gas_chamber_style",
};

- (void)migrateOldSettings
{
    NSString *YOSPOSStyle = self[OldSettingsKeys.yosposStyle];
	NSString *newYOSPOSStyle = [self themeNameForForumID:@"219"];
    if ([YOSPOSStyle isEqualToString:@"green"] || (!YOSPOSStyle && !newYOSPOSStyle)) { //Defaults to green YOSPOS if nothing was ever set
        newYOSPOSStyle = @"YOSPOS";
    } else if ([YOSPOSStyle isEqualToString:@"amber"]) {
        newYOSPOSStyle = @"YOSPOS (amber)";
    } else if ([YOSPOSStyle isEqualToString:@"macinyos"]) {
       newYOSPOSStyle = @"Macinyos";
    } else if ([YOSPOSStyle isEqualToString:@"winpos95"]) {
        newYOSPOSStyle = @"Winpos 95";
    }
	
	[self setThemeName:newYOSPOSStyle forForumID:@"219"];
	self[OldSettingsKeys.yosposStyle] = nil;
	
    
    NSString *FYADStyle = self[OldSettingsKeys.fyadStyle];
	NSString *newFYADStyle = [self themeNameForForumID:@"26"];
    if ([FYADStyle isEqualToString:@"pink"] || (!FYADStyle && !newFYADStyle)) { //Defaults to pink FYAD if nothing was ever set
        newFYADStyle = @"FYAD";
    }
	
	[self setThemeName:newFYADStyle forForumID:@"26"];
	self[OldSettingsKeys.fyadStyle] = nil;

    
    NSString *gasChamberStyle = self[OldSettingsKeys.gasChamberStyle];
	NSString *newGasChamberStyle = [self themeNameForForumID:@"25"];
    if ([gasChamberStyle isEqualToString:@"sickly"] || (!gasChamberStyle && !newGasChamberStyle)) { //Defaults to sickly Gas Chamber if nothing was ever set
       newGasChamberStyle = @"Gas Chamber";
    }
	
	[self setThemeName:newGasChamberStyle forForumID:@"25"];
	self[OldSettingsKeys.gasChamberStyle] = nil;
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

- (NSString *)themeNameForForumID:(NSString *)forumID
{
    return self[[NSString stringWithFormat:@"theme-%@", forumID]];
}

- (void)setThemeName:(NSString *)themeName forForumID:(NSString *)forumID
{
    self[[NSString stringWithFormat:@"theme-%@", forumID]] = themeName;
}

- (id)objectForKeyedSubscript:(id)key
{
    return [[NSUserDefaults standardUserDefaults] objectForKey:key];
}

- (void)setObject:(id)object forKeyedSubscript:(id <NSCopying>)key
{
    NSParameterAssert(key);
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
};
