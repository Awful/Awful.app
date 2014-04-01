//  AwfulNewPMNotifierAgent.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulNewPMNotifierAgent.h"
#import "AwfulForumsClient.h"
#import "AwfulPrivateMessage.h"

@interface AwfulNewPMNotifierAgent ()

@property (nonatomic) NSDate *lastCheckDate;

@end


@implementation AwfulNewPMNotifierAgent

+ (instancetype)agent
{
    static AwfulNewPMNotifierAgent *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [self new];
    });
    return instance;
}

- (NSDate *)lastCheckDate
{
    return [[NSUserDefaults standardUserDefaults] objectForKey:kLastMessageCheckDate];
}

- (void)setLastCheckDate:(NSDate *)lastCheckDate
{
    [[NSUserDefaults standardUserDefaults] setObject:lastCheckDate forKey:kLastMessageCheckDate];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

static NSString * const kLastMessageCheckDate = @"com.awfulapp.Awful.LastMessageCheckDate";

- (void)checkForNewMessages
{
    __weak __typeof__(self) weakSelf = self;
    [[AwfulForumsClient client] countUnreadPrivateMessagesInInboxAndThen:^(NSError *error, NSInteger unreadMessageCount) {
        __typeof__(self) self = weakSelf;
        if (error) {
            NSLog(@"%s error checking for new private messages: %@", __PRETTY_FUNCTION__, error);
            return;
        }
        self.lastCheckDate = [NSDate date];
        [[NSNotificationCenter defaultCenter] postNotificationName:AwfulNewPrivateMessagesNotification
                                                            object:self
                                                          userInfo:@{ AwfulNewPrivateMessageCountKey: @(unreadMessageCount) }];
    }];
}

@end

NSString * const AwfulNewPrivateMessagesNotification = @"AwfulNewPrivateMessagesNotification";

NSString * const AwfulNewPrivateMessageCountKey = @"AwfulNewPrivateMessageCountKey";
