//  AwfulRefreshMinder.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulRefreshMinder.h"

@implementation AwfulRefreshMinder

+ (instancetype)minder
{
    static AwfulRefreshMinder *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] initWithUserDefaults:[NSUserDefaults standardUserDefaults]];
    });
    return instance;
}

- (id)initWithUserDefaults:(NSUserDefaults *)userDefaults
{
    self = [super init];
    if (!self) return nil;
    
    _userDefaults = userDefaults;
    
    return self;
}

- (BOOL)shouldRefreshForum:(AwfulForum *)forum
{
    NSDate *lastRefresh = forum.lastRefresh;
    return !lastRefresh || [[NSDate date] timeIntervalSinceDate:lastRefresh] > 60 * 15;
}

- (void)didFinishRefreshingForum:(AwfulForum *)forum
{
    forum.lastRefresh = [NSDate date];
}

- (BOOL)shouldRefreshFilteredForum:(AwfulForum *)forum
{
    NSDate *lastRefresh = forum.lastFilteredRefresh;
    return !lastRefresh || [[NSDate date] timeIntervalSinceDate:lastRefresh] > 60 * 15;
}

- (void)didFinishRefreshingFilteredForum:(AwfulForum *)forum
{
    forum.lastFilteredRefresh = [NSDate date];
}

- (void)forgetForum:(AwfulForum *)forum
{
    forum.lastRefresh = nil;
    forum.lastFilteredRefresh = nil;
}

// Specify the refresh dates we care about here, and the infrastructure for the public API will be generated thereafter.
// Fields are: X(public name, NSUSerDefaults key, seconds between refreshes). The X should be blindly copied when adding a new row.
#define REFRESH_DATES \
    X(Avatar, @"LastLoggedInUserAvatarRefreshDate", 60 * 10) \
    X(Bookmarks, @"com.awfulapp.Awful.LastBookmarksRefreshDate", 60 * 10) \
    X(ForumList, @"com.awfulapp.Awful.LastForumRefreshDate", 60 * 60 * 6) \
    X(LoggedInUser, @"LastLoggedInUserRefreshDate", 60 * 5) \
    X(PrivateMessagesInbox, @"LastPrivateMessageInboxRefreshDate", 60 * 10) \

// X Macro good times ahead.

- (void)forgetEverything
{
    #define X(_, key, ...) [self.userDefaults removeObjectForKey:key];
    REFRESH_DATES
    #undef X
}

#define X(name, key, interval) \
- (BOOL)shouldRefresh##name \
{ \
    NSDate *lastRefresh = [self.userDefaults objectForKey:(key)]; \
    return !lastRefresh || [[NSDate date] timeIntervalSinceDate:lastRefresh] > (interval); \
} \
\
- (void)didFinishRefreshing##name \
{ \
    [self.userDefaults setObject:[NSDate date] forKey:(key)]; \
}
REFRESH_DATES
#undef X

@end
