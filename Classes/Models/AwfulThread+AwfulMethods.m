//
//  AwfulThread+AwfulMethods.m
//  Awful
//
//  Created by Sean Berry on 3/28/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulThread+AwfulMethods.h"
#import "AwfulUtil.h"
#import "TFHpple.h"
#import "TFHppleElement.h"
#import "XPathQuery.h"

@implementation AwfulThread (AwfulMethods)

+(NSArray *)threadsForForum : (AwfulForum *)forum
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"AwfulThread"];
    NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"lastPostDate" ascending:YES];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"forum=%@", forum];
    [fetchRequest setSortDescriptors:[NSArray arrayWithObject:sort]];
    [fetchRequest setPredicate:predicate];
    
    NSError *err = nil;
    NSArray *threads = [ApplicationDelegate.managedObjectContext executeFetchRequest:fetchRequest error:&err];
    if(err != nil) {
        NSLog(@"failed to load threads %@", [err localizedDescription]);
        return [NSArray array];
    }
    return threads;
}

+(void)removeOldThreadsForForum : (AwfulForum *)forum;
{
    NSArray *threads = [AwfulThread threadsForForum:forum];
    for(AwfulThread *thread in threads) {
        if(![[thread isBookmarked] boolValue]) {
            [ApplicationDelegate.managedObjectContext deleteObject:thread];
        }
    }
}

+(NSArray *)bookmarkedThreads
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"AwfulThread"];
    NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"lastPostDate" ascending:YES];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"isBookmarked=YES"];
    [fetchRequest setSortDescriptors:[NSArray arrayWithObject:sort]];
    [fetchRequest setPredicate:predicate];
    
    NSError *err = nil;
    NSArray *threads = [ApplicationDelegate.managedObjectContext executeFetchRequest:fetchRequest error:&err];
    if(err != nil) {
        NSLog(@"failed to load threads %@", [err localizedDescription]);
        return [NSArray array];
    }
    return threads;
}

+(void)removeBookmarkedThreads
{
    NSArray *threads = [AwfulThread bookmarkedThreads];
    for(AwfulThread *thread in threads) {
        [ApplicationDelegate.managedObjectContext deleteObject:thread];
    }
}

+(NSString *)buildThreadParseString
{
    NSString *reg_str = @"//tr[@class='thread']";
    NSString *reg_category_str = @"//tr[@class='thread category0']|//tr[@class='thread category1']|//tr[@class='thread category2']";
    
    NSString *closed_base_str = @"//tr[@class='thread closed']|//tr[@class='thread seen closed']";
    NSString *closed_category_str = @"//tr[@class='thread seen category0 closed']|//tr[@class='thread seen category1 closed']|//tr[@class='thread seen category2 closed']";
    NSString *closed_str = [closed_base_str stringByAppendingFormat:@"|%@", closed_category_str];
    
    NSString *seen_base_str = @"//tr[@class='thread seen']";
    NSString *seen_category_str = @"//tr[@class='thread seen category0']|//tr[@class='thread seen category1']|//tr[@class='thread seen category2']";
    NSString *seen_str = [seen_base_str stringByAppendingFormat:@"|%@", seen_category_str];
    
    NSString *big_str = [reg_str stringByAppendingFormat:@"|%@|%@|%@", reg_category_str, closed_str, seen_str];
    return big_str;
}

+(NSMutableArray *)parseThreadsForBookmarksWithData : (NSData *)data
{
    NSMutableArray *existing_threads = [NSMutableArray arrayWithArray:[AwfulThread bookmarkedThreads]];
    return [AwfulThread parseThreadsWithData:data existingThreads:existing_threads];
}

+(NSMutableArray *)parseThreadsFromForumData : (NSData *)data forForum : (AwfulForum *)forum
{
    NSMutableArray *existing_threads = [NSMutableArray arrayWithArray:[AwfulThread threadsForForum:forum]];
    return [AwfulThread parseThreadsWithData:data existingThreads:existing_threads];
}

+(NSMutableArray *)parseThreadsWithData : (NSData *)data existingThreads : (NSMutableArray *)existing_threads
{
    NSString *raw_str = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
    NSData *converted = [raw_str dataUsingEncoding:NSUTF8StringEncoding];
    TFHpple *hpple = [[TFHpple alloc] initWithHTMLData:converted];
    
    NSMutableArray *threads = [[NSMutableArray alloc] init];
    
    NSString *big_str = [AwfulThread buildThreadParseString];
    NSArray *post_strings = PerformRawHTMLXPathQuery(hpple.data, big_str);
    
    for(NSString *thread_html in post_strings) {
        
        @autoreleasepool {
            
            TFHpple *thread_base = [[TFHpple alloc] initWithHTMLData:[thread_html dataUsingEncoding:NSUTF8StringEncoding]];
                        
            TFHppleElement *tid_element = [thread_base searchForSingle:big_str];
            NSString *tid = nil;
            if(tid_element != nil) {
                NSString *tid_str = [tid_element objectForKey:@"id"];
                if(tid_str == nil) {
                    // announcements don't have thread_ids, they get linked to announcement.php
                    // gonna disregard announcements for now
                    continue;
                } else {
                    tid = [tid_str substringFromIndex:6];
                }
            }
            
            if(tid != nil) {
                
                BOOL found = NO;
                for(AwfulThread *existing_thread in existing_threads) {
                    if([existing_thread.threadID isEqualToString:tid]) {
                        [AwfulThread populateAwfulThread:existing_thread fromBase:thread_base];
                        [threads addObject:existing_thread];
                        found = YES;
                        break;
                    }
                }
                
                [existing_threads removeObjectsInArray:threads];
                
                if(!found) {
                    AwfulThread *newThread = [NSEntityDescription insertNewObjectForEntityForName:@"AwfulThread" inManagedObjectContext:ApplicationDelegate.managedObjectContext];
                    [AwfulThread populateAwfulThread:newThread fromBase:thread_base];
                    [threads addObject:newThread];
                }
            }
        }
    }
    
    return threads;
}

+(void)populateAwfulThread : (AwfulThread *)thread fromBase : (TFHpple *)thread_base
{
    NSString *category_zero = @"//tr[@class='thread category0']|//tr[@class='thread seen category0']";
    NSString *category_one = @"//tr[@class='thread category1']|//tr[@class='thread seen category1']";
    NSString *category_two = @"//tr[@class='thread category2']|//tr[@class='thread seen category2']";
    NSString *seen_base_str = @"//tr[@class='thread seen']";
    NSString *seen_category_str = @"//tr[@class='thread seen category0']|//tr[@class='thread seen category1']|//tr[@class='thread seen category2']";
    NSString *seen_str = [seen_base_str stringByAppendingFormat:@"|%@", seen_category_str];
    NSString *closed_base_str = @"//tr[@class='thread closed']|//tr[@class='thread seen closed']";
    NSString *closed_category_str = @"//tr[@class='thread seen category0 closed']|//tr[@class='thread seen category1 closed']|//tr[@class='thread seen category2 closed']";
    NSString *closed_str = [closed_base_str stringByAppendingFormat:@"|%@", closed_category_str];
    
    TFHppleElement *title = [thread_base searchForSingle:@"//a[@class='thread_title']"];
    if(title != nil) {
        thread.title = [title content];
    }
    
    TFHppleElement *sticky = [thread_base searchForSingle:@"//td[@class='title title_sticky']"];
    if(sticky != nil) {
        thread.isStickied = [NSNumber numberWithBool:YES];
    }
    
    TFHppleElement *icon = [thread_base searchForSingle:@"//td[@class='icon']/img"];
    if(icon != nil) {
        NSString *icon_str = [icon objectForKey:@"src"];
        thread.threadIconImageURL = [NSURL URLWithString:icon_str];
    }
    
    TFHppleElement *author = [thread_base searchForSingle:@"//td[@class='author']/a"];
    if(author != nil) {
        thread.authorName = [author content];
    }
    
    TFHppleElement *seen = [thread_base searchForSingle:seen_str];
    if(seen != nil) {
        thread.seen = [NSNumber numberWithBool:YES];
    }
    
    TFHppleElement *locked = [thread_base searchForSingle:closed_str];
    if(locked != nil) {
        thread.isLocked = [NSNumber numberWithBool:YES];
    }
    
    thread.starCategory = [NSNumber numberWithInt:AwfulStarCategoryNone];
    TFHppleElement *cat_zero = [thread_base searchForSingle:category_zero];
    if(cat_zero != nil) {
        thread.starCategory = AwfulStarCategoryBlue;
    }
    
    TFHppleElement *cat_one = [thread_base searchForSingle:category_one];
    if(cat_one != nil) {
        thread.starCategory = [NSNumber numberWithInt:AwfulStarCategoryRed];
    }
    
    TFHppleElement *cat_two = [thread_base searchForSingle:category_two];
    if(cat_two != nil) {
        thread.starCategory = [NSNumber numberWithInt:AwfulStarCategoryYellow];
    }
    
    thread.totalUnreadPosts = [NSNumber numberWithInt:-1];
    TFHppleElement *unread = [thread_base searchForSingle:@"//a[@class='count']/b"];
    if(unread != nil) {
        NSString *unread_str = [unread content];
        thread.totalUnreadPosts = [NSNumber numberWithInt:[unread_str intValue]];
    } else {
        unread = [thread_base searchForSingle:@"//a[@class='x']"];
        if(unread != nil) {
            // they've read it all
            thread.totalUnreadPosts = [NSNumber numberWithInt:0];
        }
    }
    
    TFHppleElement *total = [thread_base searchForSingle:@"//td[@class='replies']/a"];
    if(total != nil) {
        thread.totalReplies = [NSNumber numberWithInt:[[total content] intValue]];
    } else {
        total = [thread_base searchForSingle:@"//td[@class='replies']"];
        if(total != nil) {
            thread.totalReplies = [NSNumber numberWithInt:[[total content] intValue]];
        }
    }
    
    TFHppleElement *rating = [thread_base searchForSingle:@"//td[@class='rating']/img"];
    if(rating != nil) {
        NSString *rating_str = [rating objectForKey:@"src"];
        NSURL *rating_url = [NSURL URLWithString:rating_str];
        NSString *last = [rating_url lastPathComponent];
        if([last isEqualToString:@"5stars.gif"]) {
            thread.threadRating = [NSNumber numberWithInt:5];
        } else if([last isEqualToString:@"4stars.gif"]) {
            thread.threadRating = [NSNumber numberWithInt:4];
        } else if([last isEqualToString:@"3stars.gif"]) {
            thread.threadRating = [NSNumber numberWithInt:3];
        } else if([last isEqualToString:@"2stars.gif"]) {
            thread.threadRating = [NSNumber numberWithInt:2];
        } else if([last isEqualToString:@"1stars.gif"]) {
            thread.threadRating = [NSNumber numberWithInt:1];
        } else if([last isEqualToString:@"0stars.gif"]) {
            thread.threadRating = [NSNumber numberWithInt:0];
        }
    }
    
    TFHppleElement *date = [thread_base searchForSingle:@"//td[@class='lastpost']//div[@class='date']"];
    TFHppleElement *last_author = [thread_base searchForSingle:@"//td[@class='lastpost']//a[@class='author']"];
    
    if(date != nil && last_author != nil) {
        thread.lastPostAuthorName = [NSString stringWithFormat:@"%@", [last_author content]];
        
        static NSDateFormatter *df = nil;
        if(df == nil) {
            df = [[NSDateFormatter alloc] init];
            [df setTimeZone:[NSTimeZone localTimeZone]];
            [df setDateFormat:@"HH:mm MMM d, yyyy"];
        }
        
        NSDate *myDate = [df dateFromString:[date content]];
        if(myDate != nil) {
            thread.lastPostDate = myDate;
        }
    }
}

@end
