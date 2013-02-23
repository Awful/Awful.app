//
//  AwfulPrivateMessage.m
//  Awful
//
//  Created by Nolan Waite on 13-02-22.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPrivateMessage.h"
#import "AwfulDataStack.h"
#import "AwfulParsing.h"
#import "AwfulUser.h"

@implementation AwfulPrivateMessage

- (NSString *)firstIconName
{
    NSString *basename = [[self.messageIconImageURL lastPathComponent]
                          stringByDeletingPathExtension];
    return [basename stringByAppendingPathExtension:@"png"];
}

+ (instancetype)privateMessageCreatedOrUpdatedWithParsedInfo:(PrivateMessageParsedInfo *)info
{
    AwfulPrivateMessage *message = [self firstMatchingPredicate:@"messageID = %@", info.messageID];
    if (!message) {
        message = [AwfulPrivateMessage insertNew];
    }
    [info applyToObject:message];
    if (info.from) {
        AwfulUser *from = [AwfulUser firstMatchingPredicate:@"username = %@", info.from.username];
        if (!from) {
            from = [AwfulUser insertNew];
        }
        [info.from applyToObject:from];
        message.from = from;
    }
    if (info.to) {
        AwfulUser *to = [AwfulUser firstMatchingPredicate:@"username = %@", info.to.username];
        if (!to) {
            to = [AwfulUser insertNew];
        }
        [info.to applyToObject:to];
        message.to = to;
    }
    return message;
}

+ (NSArray *)privateMessagesCreatedOrUpdatedWithParsedInfo:(NSArray *)messageInfos
{
    NSMutableDictionary *existingPMs = [NSMutableDictionary new];
    NSArray *messageIDs = [messageInfos valueForKey:@"messageID"];
    for (AwfulPrivateMessage *msg in [self fetchAllMatchingPredicate:@"messageID IN %@", messageIDs]) {
        existingPMs[msg.messageID] = msg;
    }
    NSMutableDictionary *existingUsers = [NSMutableDictionary new];
    NSArray *usernames = [messageInfos valueForKeyPath:@"from"];
    for (AwfulUser *user in [AwfulUser fetchAllMatchingPredicate:@"username IN %@", usernames]) {
        existingUsers[user.username] = user;
    }
    
    for (PrivateMessageParsedInfo *info in messageInfos) {
        AwfulPrivateMessage *msg = existingPMs[info.messageID] ?: [AwfulPrivateMessage insertNew];
        [info applyToObject:msg];
        if (!msg.from) msg.from = [AwfulUser insertNew];
        [info.from applyToObject:msg.from];
        existingUsers[msg.from.username] = msg.from;
        existingPMs[msg.messageID] = msg;
    }
    [[AwfulDataStack sharedDataStack] save];
    return [existingPMs allValues];
}

@end
