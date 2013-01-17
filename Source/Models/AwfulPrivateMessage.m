#import "AwfulPrivateMessage.h"
#import "AwfulParsing+PrivateMessages.h"
#import "AwfulUser.h"
#import "AwfulDataStack.h"
#import "NSManagedObject+Awful.h"

@implementation AwfulPrivateMessage

- (NSString *)firstIconName
{
    NSString *basename = [[self.messageIconImageURL lastPathComponent]
                          stringByDeletingPathExtension];
    return [basename stringByAppendingPathExtension:@"png"];
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
