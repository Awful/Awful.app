//  AwfulPrivateMessage.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPrivateMessage.h"

@implementation AwfulPrivateMessage

@dynamic forwarded;
@dynamic innerHTML;
@dynamic messageID;
@dynamic replied;
@dynamic seen;
@dynamic sentDate;
@dynamic subject;
@dynamic threadTagURL;
@dynamic from;
@dynamic to;

- (NSString *)firstIconName
{
    NSString *basename = [self.threadTagURL.lastPathComponent stringByDeletingPathExtension];
    return [basename stringByAppendingPathExtension:@"png"];
}

+ (instancetype)firstOrNewPrivateMessageWithMessageID:(NSString *)messageID
                               inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    AwfulPrivateMessage *message = [self fetchArbitraryInManagedObjectContext:managedObjectContext
                                                      matchingPredicateFormat:@"messageID = %@", messageID];
    if (!message) {
        message = [self insertInManagedObjectContext:managedObjectContext];
        message.messageID = messageID;
    }
    return message;
}

@end
