//
//  AwfulParsing+Lepers.h
//  Awful
//
//  Created by me on 1/29/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulParsing.h"
#import "AwfulLeper.h"

@interface LepersParsedInfo : ParsedInfo
@property (readonly, nonatomic) AwfulLeperType banType;
@property (readonly, copy, nonatomic) NSString *postID;
@property (readonly, nonatomic) NSDate *date;
@property (readonly, copy, nonatomic) NSString *bannedUserID;
@property (readonly, copy, nonatomic) NSString *bannedUserName;
@property (readonly, copy, nonatomic) NSString *reason;
@property (readonly, copy, nonatomic) NSString *modUserID;
@property (readonly, copy, nonatomic) NSString *modUserName;
@property (readonly, copy, nonatomic) NSString *adminUserID;
@property (readonly, copy, nonatomic) NSString *adminUserName;

@property (readonly, nonatomic) NSString *banID;

+ (NSArray*)lepersWithHTMLData:(NSData*)data;
@end


typedef enum {
    LeperTableColumnType = 0,
    LeperTableColumnDate,
    LeperTableColumnJerk,
    LeperTableColumnReason,
    LeperTableColumnMod,
    LeperTableColumnAdmin
} LeperTableColumn;

extern AwfulLeperType BanTypeFromString(NSString* s);