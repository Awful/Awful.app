//  NewMessageChecker.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "NewMessageChecker.h"
#import "AwfulForumsClient.h"
@import UIKit;

#import "Awful-Swift.h"

@interface NewMessageChecker ()

@property (assign, nonatomic) NSInteger unreadCount;
@property (strong, nonatomic) NSTimer *timer;

@end

@implementation NewMessageChecker

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (id)init
{
    if ((self = [super init])) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillEnterForeground:)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidEnterBackground:)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
        [self startTimer];
    }
    return self;
}

- (NSInteger)unreadCount
{
    return [[NSUserDefaults standardUserDefaults] integerForKey:UnreadMessageCountKey];
}

- (void)setUnreadCount:(NSInteger)unreadCount
{
    [[NSUserDefaults standardUserDefaults] setInteger:unreadCount forKey:UnreadMessageCountKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:NewMessageCheckerUnreadCountDidChangeNotification
                                                        object:self
                                                      userInfo:@{NewMessageCheckerUnreadCountKey: @(unreadCount)}];
}

- (void)decrementUnreadCount
{
    if (self.unreadCount > 0) {
        self.unreadCount--;
    }
}

static NSString * const UnreadMessageCountKey = @"AwfulUnreadMessages";

+ (instancetype)sharedChecker
{
    static NewMessageChecker *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [self new];
    });
    return instance;
}

- (void)applicationWillEnterForeground:(NSNotification *)note
{
    [self refreshIfNecessary];
    [self startTimer];
}

- (void)applicationDidEnterBackground:(NSNotification *)note
{
    [_timer invalidate];
    _timer = nil;
}

- (void)startTimer
{
    NSTimeInterval interval = [[[RefreshMinder sharedMinder] suggestedDateToRefreshNewPrivateMessages] timeIntervalSinceNow];
    _timer = [NSTimer scheduledTimerWithTimeInterval:interval target:self selector:@selector(timerDidFire:) userInfo:nil repeats:NO];
}

- (void)timerDidFire:(NSTimer *)timer
{
    _timer = nil;
    [self refreshIfNecessary];
}

- (void)refreshIfNecessary
{
    if ([RefreshMinder sharedMinder].shouldRefreshNewPrivateMessages) {
        __weak __typeof__(self) weakSelf = self;
        [[AwfulForumsClient client] countUnreadPrivateMessagesInInboxAndThen:^(NSError *error, NSInteger unreadCount) {
            __typeof__(self) self = weakSelf;
            if (error) {
                NSLog(@"%s error checking for new private messages: %@", __PRETTY_FUNCTION__, error);
                return;
            }
            self.unreadCount = unreadCount;
            [[RefreshMinder sharedMinder] didRefreshNewPrivateMessages];
        }];
    }
}

@end

NSString * const NewMessageCheckerUnreadCountDidChangeNotification = @"Awful.NewMessageCheckerUnreadCountDidChangeNotification";
NSString * const NewMessageCheckerUnreadCountKey = @"unreadCount";
