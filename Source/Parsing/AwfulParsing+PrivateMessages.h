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
+(NSMutableArray *)parsePMListWithData:(NSData*)data;
+(NSMutableArray *)parsePM:(AwfulPrivateMessage*)message withData:(NSData*)data;
@end
