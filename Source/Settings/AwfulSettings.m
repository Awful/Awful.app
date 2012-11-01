//
//  AwfulSettings.m
//  Awful
//
//  Created by Nolan Waite on 12-04-21.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulSettings.h"
#import "AwfulUser.h"

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

#define BOOL_PROPERTY(__key, __get, __set) \
- (BOOL)__get \
{ \
    return [[NSUserDefaults standardUserDefaults] boolForKey:__key]; \
} \
\
- (void)__set:(BOOL)val \
{ \
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; \
    [defaults setBool:val forKey:__key]; \
    [defaults synchronize]; \
}

BOOL_PROPERTY(@"show_avatars", showAvatars, setShowAvatars)

BOOL_PROPERTY(@"show_images", showImages, setShowImages)

static NSString * const kFirstTab = @"default_load";
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
    NSString *value = [[NSUserDefaults standardUserDefaults] stringForKey:kFirstTab];
    if ([value isEqualToString:AwfulFirstTabs.Forums]) {
        return AwfulFirstTabForums;
    } else if ([value isEqualToString:AwfulFirstTabs.Favorites]) {
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
    }
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:value forKey:kFirstTab];
    [defaults synchronize];
}

BOOL_PROPERTY(@"highlight_own_quotes", highlightOwnQuotes, setHighlightOwnQuotes)

BOOL_PROPERTY(@"highlight_own_mentions", highlightOwnMentions, setHighlightOwnMentions)

BOOL_PROPERTY(@"dark_theme", darkTheme, setDarkTheme)

static NSString * const kCurrentUser = @"current_user";

- (AwfulUser *)currentUser
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [AwfulUser userWithDictionaryRepresentation:[defaults objectForKey:kCurrentUser]];
}

- (void)setCurrentUser:(AwfulUser *)currentUser
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[currentUser dictionaryRepresentation] forKey:kCurrentUser];
    [defaults synchronize];
}

@end
