//  AwfulPrivateMessage.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "_AwfulPrivateMessage.h"
@class PrivateMessageParsedInfo;
@class PrivateMessageFolderParsedInfo;

@interface AwfulPrivateMessage : _AwfulPrivateMessage {}

@property (readonly, nonatomic) NSString *firstIconName;

+ (instancetype)privateMessageWithParsedInfo:(PrivateMessageParsedInfo *)info
                      inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

+ (NSArray *)privateMessagesWithFolderParsedInfo:(PrivateMessageFolderParsedInfo *)info
                          inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

@end
