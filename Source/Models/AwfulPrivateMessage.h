//
//  AwfulPrivateMessage.h
//  Awful
//
//  Created by Nolan Waite on 13-02-22.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "_AwfulPrivateMessage.h"
@class PrivateMessageParsedInfo;
@class PrivateMessageFolderParsedInfo;

@interface AwfulPrivateMessage : _AwfulPrivateMessage {}

@property (readonly, nonatomic) NSString *firstIconName;

+ (instancetype)privateMessageWithParsedInfo:(PrivateMessageParsedInfo *)info;

+ (NSArray *)privateMessagesWithFolderParsedInfo:(PrivateMessageFolderParsedInfo *)info;

@end
