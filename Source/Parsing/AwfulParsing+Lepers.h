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
@property (readonly, nonatomic) NSDate *banDate;
@property (readonly, copy, nonatomic) NSString *bannedUserID;
@property (readonly, copy, nonatomic) NSString *banReason;
@property (readonly, copy, nonatomic) NSString *modUserID;
@property (readonly, copy, nonatomic) NSString *adminUserID;

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