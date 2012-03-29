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

+(NSMutableArray *)parseThreadsFromForumData : (NSData *)data forForum : (AwfulForum *)forum;
+(NSMutableArray *)parseThreadsForBookmarksWithData : (NSData *)data;
+(NSMutableArray *)parseThreadsWithData : (NSData *)data existingThreads : (NSMutableArray *)existing_threads forum : (AwfulForum *)forum;

+(void)populateAwfulThread : (AwfulThread *)thread fromBase : (TFHpple *)thread_base;
+(NSString *)buildThreadParseString;

@end
