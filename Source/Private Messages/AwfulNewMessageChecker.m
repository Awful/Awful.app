//  AwfulNewMessageChecker.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulNewMessageChecker.h"
#import "AwfulForumsClient.h"
#import "AwfulRefreshMinder.h"
@import UIKit;

@interface AwfulNewMessageChecker ()

@property (assign, nonatomic) NSInteger unreadMessageCount;

@end

@implementation AwfulNewMessageChecker
{
    NSTimer *_timer;
}

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

- (NSInteger)unreadMessageCount
{
    return [[NSUserDefaults standardUserDefaults] integerForKey:UnreadMessageCountKey];
}

- (void)setUnreadMessageCount:(NSInteger)unreadMessageCount
{
    [[NSUserDefaults standardUserDefaults] setInteger:unreadMessageCount forKey:UnreadMessageCountKey];
}

static NSString * const UnreadMessageCountKey = @"AwfulUnreadMessages";

+ (instancetype)checker
{
    static AwfulNewMessageChecker *instance = nil;
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
    NSTimeInterval interval = [[[AwfulRefreshMinder minder] suggestedDateToRefreshNewPrivateMessages] timeIntervalSinceNow];
    _timer = [NSTimer scheduledTimerWithTimeInterval:interval target:self selector:@selector(timerDidFire:) userInfo:nil repeats:NO];
}

- (void)timerDidFire:(NSTimer *)timer
{
    _timer = nil;
    [self refreshIfNecessary];
}

- (void)refreshIfNecessary
{
    if ([[AwfulRefreshMinder minder] shouldRefreshNewPrivateMessages]) {
        __weak __typeof__(self) weakSelf = self;
        [[AwfulForumsClient client] countUnreadPrivateMessagesInInboxAndThen:^(NSError *error, NSInteger unreadMessageCount) {
            __typeof__(self) self = weakSelf;
            if (error) {
                NSLog(@"%s error checking for new private messages: %@", __PRETTY_FUNCTION__, error);
                return;
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:AwfulDidFinishCheckingNewPrivateMessagesNotification
                                                                object:self
                                                              userInfo:@{ AwfulNewPrivateMessageCountKey: @(unreadMessageCount) }];
            self.unreadMessageCount = unreadMessageCount;
            [[AwfulRefreshMinder minder] didFinishRefreshingNewPrivateMessages];
        }];
    }
}

@end

NSString * const AwfulDidFinishCheckingNewPrivateMessagesNotification = @"AwfulNewPrivateMessagesNotification";

NSString * const AwfulNewPrivateMessageCountKey = @"AwfulNewPrivateMessageCountKey";
