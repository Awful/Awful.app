//
//  AwfulThread.h
//  Awful
//
//  Created by Nolan Waite on 12-05-17.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "_AwfulThread.h"

@interface AwfulThread : _AwfulThread

+ (NSArray *)bookmarkedThreads;
+ (void)removeBookmarkedThreads;

@property (readonly, nonatomic) NSURL *firstIconURL;
@property (readonly, nonatomic) NSURL *secondIconURL;

+ (NSArray *)threadsCreatedOrUpdatedWithParsedInfo:(NSArray *)threadInfos;

@end


typedef enum {
    AwfulStarCategoryBlue = 0,
    AwfulStarCategoryRed,
    AwfulStarCategoryYellow,
    AwfulStarCategoryNone
} AwfulStarCategory;


extern NSString * const AwfulThreadDidUpdateNotification;
