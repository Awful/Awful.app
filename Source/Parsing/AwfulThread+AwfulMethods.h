//
//  AwfulThread+AwfulMethods.h
//  Awful
//
//  Created by Sean Berry on 3/28/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulThread.h"

@class TFHpple;

@interface AwfulThread (AwfulMethods)

+(NSArray *)threadsForForum : (AwfulForum *)forum;
+(void)removeOldThreadsForForum : (AwfulForum *)forum;
+(NSArray *)bookmarkedThreads;
+(void)removeBookmarkedThreads;

+(NSMutableArray *)parseThreadsWithData : (NSData *)data forForum : (AwfulForum *)forum;
+(NSMutableArray *)parseBookmarkedThreadsWithData : (NSData *)data;

+(void)populateAwfulThread : (AwfulThread *)thread fromBase : (TFHpple *)thread_base;

-(NSURL *)firstIconURL;
-(NSURL *)secondIconURL;

@end

typedef enum {
    AwfulStarCategoryBlue = 0,
    AwfulStarCategoryRed,
    AwfulStarCategoryYellow,
    AwfulStarCategoryNone
} AwfulStarCategory;
