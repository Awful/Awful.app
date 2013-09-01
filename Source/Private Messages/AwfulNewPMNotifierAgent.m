//  AwfulNewPMNotifierAgent.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulNewPMNotifierAgent.h"
#import "AwfulHTTPClient.h"
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
    [[AwfulHTTPClient client] listPrivateMessagesAndThen:^(NSError *error, NSArray *messages)
    {
        if (error) {
            NSLog(@"error checking for new private messages: %@", error);
            return;
        }
        self.lastCheckDate = [NSDate date];
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"seen = NO"];
        NSArray *unseen = [messages filteredArrayUsingPredicate:predicate];
        NSNotificationCenter *noteCenter = [NSNotificationCenter defaultCenter];
        [noteCenter postNotificationName:AwfulNewPrivateMessagesNotification object:self
                                userInfo:@{ AwfulNewPrivateMessageCountKey: @([unseen count]) }];
    }];
}


@end


NSString * const AwfulNewPrivateMessagesNotification = @"AwfulNewPrivateMessagesNotification";
NSString * const AwfulNewPrivateMessageCountKey = @"AwfulNewPrivateMessageCountKey";
