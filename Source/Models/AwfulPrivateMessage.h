//
//  AwfulPrivateMessage.h
//  Awful
//
//  Created by Nolan Waite on 13-02-22.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "_AwfulPrivateMessage.h"
@class PrivateMessageParsedInfo;

@interface AwfulPrivateMessage : _AwfulPrivateMessage {}

@property (readonly, nonatomic) NSString *firstIconName;

+ (instancetype)privateMessageCreatedOrUpdatedWithParsedInfo:(PrivateMessageParsedInfo *)info;

+ (NSArray *)privateMessagesCreatedOrUpdatedWithParsedInfo:(NSArray *)messageInfos;

@end
