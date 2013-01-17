//
//  AwfulParsing+PrivateMessages.h
//  Awful
//
//  Created by me on 1/7/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulParsing.h"
#import "AwfulPrivateMessage.h"

@interface PrivateMessageParsedInfo : ParsedInfo
@property (readonly, copy, nonatomic) NSString *messageID;
@property (readonly, copy, nonatomic) NSString *subject;
@property (readonly, nonatomic) NSDate* sent;
@property (readonly, nonatomic) NSURL *messageIconImageURL;
@property (readonly, nonatomic) UserParsedInfo *from;
@property (readonly, nonatomic) BOOL seen;
@property (readonly, nonatomic) BOOL replied;
@property (readonly, nonatomic) NSString *innerHTML;

+ (NSArray *)messagesWithHTMLData:(NSData *)htmlData;
+ (void)parsePM:(AwfulPrivateMessage*)message withData:(NSData*)data;
@end
