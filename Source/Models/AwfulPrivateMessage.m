//
//  AwfulPrivateMessage.m
//  Awful
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import "AwfulPrivateMessage.h"
#import "AwfulDataStack.h"
#import "AwfulParsing.h"
#import "AwfulUser.h"
#import "NSManagedObject+Awful.h"

@implementation AwfulPrivateMessage

- (NSString *)firstIconName
{
    NSString *basename = [[self.messageIconImageURL lastPathComponent]
                          stringByDeletingPathExtension];
    return [basename stringByAppendingPathExtension:@"png"];
}

+ (instancetype)privateMessageWithParsedInfo:(PrivateMessageParsedInfo *)info
{
    AwfulPrivateMessage *message = [self firstMatchingPredicate:@"messageID = %@", info.messageID];
    if (!message) {
        message = [AwfulPrivateMessage insertNew];
    }
    [info applyToObject:message];
    if (info.from) {
        AwfulUser *from;
        if (info.from.userID) {
            from = [AwfulUser firstMatchingPredicate:@"userID = %@", info.from.userID];
        }
        if (!from && info.from.username) {
            from = [AwfulUser firstMatchingPredicate:@"username = %@", info.from.username];
        }
        if (!from) {
            from = [AwfulUser insertNew];
        }
        [info.from applyToObject:from];
        message.from = from;
    }
    if (info.to) {
        AwfulUser *to = [AwfulUser firstMatchingPredicate:@"userID = %@", info.to.username];
        if (!to) {
            to = [AwfulUser insertNew];
        }
        [info.to applyToObject:to];
        message.to = to;
    }
    [[AwfulDataStack sharedDataStack] save];
    return message;
}

+ (NSArray *)privateMessagesWithFolderParsedInfo:(PrivateMessageFolderParsedInfo *)info
{
    NSMutableDictionary *existingPMs = [NSMutableDictionary new];
    NSArray *messageIDs = [info.privateMessages valueForKey:@"messageID"];
    for (AwfulPrivateMessage *msg in [self fetchAllMatchingPredicate:@"messageID IN %@", messageIDs]) {
        existingPMs[msg.messageID] = msg;
    }
    NSMutableDictionary *existingUsers = [NSMutableDictionary new];
    NSArray *usernames = [info.privateMessages valueForKeyPath:@"from.username"];
    for (AwfulUser *user in [AwfulUser fetchAllMatchingPredicate:@"username IN %@", usernames]) {
        existingUsers[user.username] = user;
    }
    
    for (PrivateMessageParsedInfo *pmInfo in info.privateMessages) {
        AwfulPrivateMessage *msg = existingPMs[pmInfo.messageID] ?: [AwfulPrivateMessage insertNew];
        [pmInfo applyToObject:msg];
        if (!msg.from) msg.from = [AwfulUser insertNew];
        [pmInfo.from applyToObject:msg.from];
        existingUsers[msg.from.username] = msg.from;
        existingPMs[msg.messageID] = msg;
    }
    [[AwfulDataStack sharedDataStack] save];
    return [existingPMs allValues];
}

@end
