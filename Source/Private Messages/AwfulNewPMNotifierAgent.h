//
//  AwfulNewPMNotifierAgent.h
//  Awful
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
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
