//
//  AwfulSettings.m
//  Awful
//
//  Created by Nolan Waite on 12-04-21.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulSettings.h"

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
    __unsafe_unretained NSString *Favorites;
    __unsafe_unretained NSString *Bookmarks;
} AwfulFirstTabs = {
    @"forumslist",
    @"favorites",
    @"bookmarks",
};

- (AwfulFirstTab)firstTab
{
    NSString *value = self[AwfulSettingsKeys.firstTab];
    if ([value isEqualToString:AwfulFirstTabs.Favorites]) {
        return AwfulFirstTabFavorites;
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
        case AwfulFirstTabFavorites: value = AwfulFirstTabs.Favorites; break;
        default: return;
    }
    self[AwfulSettingsKeys.firstTab] = value;
}

struct {
    __unsafe_unretained NSString *None;
    __unsafe_unretained NSString *Green;
    __unsafe_unretained NSString *Amber;
} AwfulYOSPOSStyles = {
    @"none",
    @"green",
    @"amber",
};


- (AwfulYOSPOSStyle)yosposStyle
{
    NSString *val = self[AwfulSettingsKeys.yosposStyle];
    if([val isEqualToString:AwfulYOSPOSStyles.None])
    {
        return AwfulYOSPOSStyleNone;
    } else if ([val isEqualToString:AwfulYOSPOSStyles.Amber])
    {
        return AwfulYOSPOSStyleAmber;
    } else if ([val isEqualToString:AwfulYOSPOSStyles.Green])
    {
        return AwfulYOSPOSStyleGreen;
    } else {
        return AwfulYOSPOSStyleGreen;

    }
    
}
-(void) setYosposStyle:(AwfulYOSPOSStyle)yosposStyle
{
    NSString *val;
    switch (yosposStyle) {
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

BOOL_PROPERTY(confirmBeforeReplying, setConfirmBeforeReplying)

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

BOOL_PROPERTY(showThreadTags, setShowThreadTags)

- (id)objectForKeyedSubscript:(id)key
{
    return [[NSUserDefaults standardUserDefaults] objectForKey:key];
}

- (void)setObject:(id)object forKeyedSubscript:(id <NSCopying>)key
{
    NSParameterAssert(key);
    [self setObject:object withoutNotifyingForKey:key];
    NSDictionary *userInfo = @{ AwfulSettingsDidChangeSettingsKey : @[ key ] };
    [[NSNotificationCenter defaultCenter] postNotificationName:AwfulSettingsDidChangeNotification
                                                        object:self
                                                      userInfo:userInfo];
}

- (void)setObject:(id)object withoutNotifyingForKey:(id)key
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (object) [defaults setObject:object forKey:(NSString *)key];
    else [defaults removeObjectForKey:(NSString *)key];
    [defaults synchronize];
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
    .confirmBeforeReplying = @"confirm_before_replying",
	.darkTheme = @"dark_theme",
    .username = @"username",
    .showThreadTags = @"show_thread_tags",
    .yosposStyle = @"yospos_style",
    .keepSidebarOpen = @"keep_sidebar_open",
};
