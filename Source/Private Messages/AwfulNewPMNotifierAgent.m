//
//  AwfulNewPMNotifierAgent.m
//  Awful
//
//  Created by me on 1/26/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulNewPMNotifierAgent.h"
#import "AwfulHTTPClient.h"
#import "AwfulPrivateMessage.h"

@implementation AwfulNewPMNotifierAgent

- (id) init
{
    self = [super init];
    return self;
}

+ (AwfulNewPMNotifierAgent *)defaultAgent
{
    static AwfulNewPMNotifierAgent *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [self new];
    });
    return instance;
}

- (void)checkForNewMessages
{
    [[AwfulHTTPClient client] listPrivateMessagesAndThen:^(NSError *error, NSArray *messages) {
        // TODO handle error
        if (error) return;
        
        _lastCheckDate = [NSDate date];
        
        int newMessageCount = 0;
        
        for (AwfulPrivateMessage* msg in messages)
        {
            if (msg.seen.boolValue == NO) {
                newMessageCount++;
            }
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName:AwfulNewPrivateMessagesNotification
                                                            object:self
                                                          userInfo:@{kAwfulNewPrivateMessageCountKey:
                                                                [NSNumber numberWithInt:newMessageCount]}
         ];
    }];
}


@end

NSString* AwfulNewPrivateMessagesNotification = @"AwfulNewPrivateMessagesNotification";
NSString* kAwfulNewPrivateMessageCountKey = @"kAwfulNewPrivateMessageCountKey";
