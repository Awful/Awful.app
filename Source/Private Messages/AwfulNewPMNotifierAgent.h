//
//  AwfulNewPMNotifierAgent.h
//  Awful
//
//  Created by me on 1/26/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AwfulNewPMNotifierAgent : NSObject

+ (instancetype)agent;

- (void)checkForNewMessages;

@property (readonly, nonatomic) NSDate *lastCheckDate;

@end

// After a successful check for new messages, this notification is sent out.
extern NSString * const AwfulNewPrivateMessagesNotification;

// An NSNumber indicating how many messages remain unseen.
extern NSString * const AwfulNewPrivateMessageCountKey;
