//  AwfulPrivateMessage.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPrivateMessage.h"

@implementation AwfulPrivateMessage

@dynamic forwarded;
@dynamic innerHTML;
@dynamic messageIconImageURL;
@dynamic messageID;
@dynamic replied;
@dynamic seen;
@dynamic sentDate;
@dynamic subject;
@dynamic from;
@dynamic to;

- (NSString *)firstIconName
{
    NSString *basename = [[self.messageIconImageURL lastPathComponent]
                          stringByDeletingPathExtension];
    return [basename stringByAppendingPathExtension:@"png"];
}

+ (instancetype)privateMessageWithParsedInfo:(PrivateMessageParsedInfo *)info
                      inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    AwfulPrivateMessage *message = [self fetchArbitraryInManagedObjectContext:managedObjectContext
                                                      matchingPredicateFormat:@"messageID = %@", info.messageID];
    if (!message) {
        message = [AwfulPrivateMessage insertInManagedObjectContext:managedObjectContext];
    }
    [info applyToObject:message];
    if (info.from) {
        AwfulUser *from;
        if (info.from.userID) {
            from = [AwfulUser fetchArbitraryInManagedObjectContext:managedObjectContext
                                           matchingPredicateFormat:@"userID = %@", info.from.userID];
        }
        if (!from && info.from.username) {
            from = [AwfulUser fetchArbitraryInManagedObjectContext:managedObjectContext
                                           matchingPredicateFormat:@"username = %@", info.from.username];
        }
        if (!from) {
            from = [AwfulUser insertInManagedObjectContext:managedObjectContext];
        }
        [info.from applyToObject:from];
        message.from = from;
    }
    if (info.to) {
        AwfulUser *to = [AwfulUser fetchArbitraryInManagedObjectContext:managedObjectContext
                                                matchingPredicateFormat:@"userID = %@", info.to.userID];
        if (!to) {
            to = [AwfulUser insertInManagedObjectContext:managedObjectContext];
        }
        [info.to applyToObject:to];
        message.to = to;
    }
    NSError *error;
    BOOL ok = [managedObjectContext save:&error];
    if (!ok) {
        NSLog(@"%s error saving parsed private message %@: %@", __PRETTY_FUNCTION__, info.messageID, error);
    }
    return message;
}

+ (NSArray *)privateMessagesWithFolderParsedInfo:(PrivateMessageFolderParsedInfo *)info
                          inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSMutableDictionary *existingPMs = [NSMutableDictionary new];
    NSArray *messageIDs = [info.privateMessages valueForKey:@"messageID"];
    for (AwfulPrivateMessage *msg in [self fetchAllInManagedObjectContext:managedObjectContext
                                                  matchingPredicateFormat:@"messageID IN %@", messageIDs]) {
        existingPMs[msg.messageID] = msg;
    }
    NSMutableDictionary *existingUsers = [NSMutableDictionary new];
    NSArray *usernames = [info.privateMessages valueForKeyPath:@"from.username"];
    for (AwfulUser *user in [AwfulUser fetchAllInManagedObjectContext:managedObjectContext
                                              matchingPredicateFormat:@"username IN %@", usernames]) {
        existingUsers[user.username] = user;
    }
    NSMutableArray *messages = [NSMutableArray new];
    for (PrivateMessageParsedInfo *pmInfo in info.privateMessages) {
        if ([pmInfo.messageID length] == 0) {
            NSLog(@"error parsing private message; skipping");
            continue;
        }
        AwfulPrivateMessage *msg = (existingPMs[pmInfo.messageID] ?:
                                    [AwfulPrivateMessage insertInManagedObjectContext:managedObjectContext]);
        [pmInfo applyToObject:msg];
        if (!msg.from) msg.from = (existingUsers[pmInfo.from.username] ?:
                                   [AwfulUser insertInManagedObjectContext:managedObjectContext]);
        [pmInfo.from applyToObject:msg.from];
        if (pmInfo.from.username) {
            existingUsers[msg.from.username] = msg.from;
        }
        [messages addObject:msg];
        existingPMs[msg.messageID] = msg;
    }
    NSError *error;
    BOOL ok = [managedObjectContext save:&error];
    if (!ok) {
        NSLog(@"%s error saving parsed message folder: %@", __PRETTY_FUNCTION__, error);
    }
    return messages;
}

@end
