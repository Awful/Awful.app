//  AwfulPrivateMessage.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulModels.h"

/**
 * An AwfulPrivateMessage object is a message sent from one user to another.
 */
@interface AwfulPrivateMessage : AwfulManagedObject

/**
 * YES if the message has been forwarded, or NO otherwise.
 */
@property (assign, nonatomic) BOOL forwarded;

/**
 * The raw HTML contents of the message.
 */
@property (copy, nonatomic) NSString *innerHTML;

/**
 * The presumably unique message ID.
 */
@property (copy, nonatomic) NSString *messageID;

/**
 * YES if the message has been replied to, or NO otherwise.
 */
@property (assign, nonatomic) BOOL replied;

/**
 * YES if the message has been read, or NO otherwise.
 */
@property (assign, nonatomic) BOOL seen;

/**
 * The date that the message was sent.
 */
@property (strong, nonatomic) NSDate *sentDate;

/**
 * The message's subject.
 */
@property (copy, nonatomic) NSString *subject;

/**
 * The message's thread tag, or nil if none was chosen by its sender.
 */
@property (strong, nonatomic) AwfulThreadTag *threadTag;

/**
 * Who sent the message.
 */
@property (strong, nonatomic) AwfulUser *from;

/**
 * Who received the message.
 */
@property (strong, nonatomic) AwfulUser *to;

/**
 * Returns an AwfulPrivateMessage object with the given message ID, inserting a new one if needed.
 */
+ (instancetype)firstOrNewPrivateMessageWithMessageID:(NSString *)messageID
                               inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

@end
