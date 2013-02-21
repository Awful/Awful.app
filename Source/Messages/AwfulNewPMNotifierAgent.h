//
//  AwfulNewPMNotifierAgent.h
//  Awful
//
//  Created by me on 1/26/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString* AwfulNewPrivateMessagesNotification;
extern NSString* kAwfulNewPrivateMessageCountKey;

@interface AwfulNewPMNotifierAgent : NSObject

+ (AwfulNewPMNotifierAgent*) defaultAgent;
- (void)checkForNewMessages;
@property (nonatomic,readonly) NSDate* lastCheckDate;
@end
