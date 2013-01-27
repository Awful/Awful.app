//
//  AwfulNewPMNotifierAgent.h
//  Awful
//
//  Created by me on 1/26/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

static NSString* AwfulNewPrivateMessagesNotification = @"AwfulNewPrivateMessagesNotification";
static NSString* kAwfulNewPrivateMessageCountKey = @"kAwfulNewPrivateMessageCountKey";

@interface AwfulNewPMNotifierAgent : NSObject

+ (AwfulNewPMNotifierAgent*) defaultAgent;
- (void)checkForNewMessages;
@end
