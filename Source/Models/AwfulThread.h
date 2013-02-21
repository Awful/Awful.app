//
//  AwfulThread.h
//  Awful
//
//  Created by Nolan Waite on 12-05-17.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "_AwfulThread.h"

@interface AwfulThread : _AwfulThread

@property (readonly, nonatomic) NSString *firstIconName;
@property (readonly, nonatomic) NSString *secondIconName;

@property (readonly, nonatomic) BOOL beenSeen;

+ (NSArray *)threadsCreatedOrUpdatedWithParsedInfo:(NSArray *)threadInfos;

+ (NSArray *)threadsCreatedOrUpdatedWithJSON:(NSDictionary *)json;

+ (instancetype)firstOrNewThreadWithThreadID:(NSString *)threadID;

@end


typedef enum {
    AwfulStarCategoryBlue = 0,
    AwfulStarCategoryRed,
    AwfulStarCategoryYellow,
    AwfulStarCategoryNone
} AwfulStarCategory;
