//
//  AwfulThread+AwfulMethods.m
//  Awful
//
//  Created by Sean Berry on 3/28/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulThread+AwfulMethods.h"
#import "TFHpple.h"
#import "TFHppleElement.h"
#import "XPathQuery.h"

@implementation AwfulThread (AwfulMethods)

+(NSArray *)threadsForForum : (AwfulForum *)forum
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:[AwfulThread entityName]];
    NSSortDescriptor *stickySort = [NSSortDescriptor sortDescriptorWithKey:@"stickyIndex" ascending:YES];
    NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"lastPostDate" ascending:NO];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(forum=%@) AND (isBookmarked==NO)", forum];
    [fetchRequest setSortDescriptors:[NSArray arrayWithObjects:stickySort, sort, nil]];
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
        if(!thread.isBookmarkedValue) {
            [ApplicationDelegate.managedObjectContext deleteObject:thread];
        }
    }
}

+(NSArray *)bookmarkedThreads
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:[AwfulThread entityName]];
    NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"lastPostDate" ascending:NO];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"isBookmarked==YES"];
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

+(NSMutableArray *)parseBookmarkedThreadsWithData : (NSData *)data
{
    NSString *raw_str = [[NSString alloc] initWithData:data encoding:NSWindowsCP1252StringEncoding];
    NSData *converted = [raw_str dataUsingEncoding:NSUTF8StringEncoding];
    TFHpple *hpple = [[TFHpple alloc] initWithHTMLData:converted];
    
    NSMutableArray *threads = [[NSMutableArray alloc] init];
    NSMutableArray *existing_threads = [NSMutableArray arrayWithArray:[AwfulThread bookmarkedThreads]];
    
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
                AwfulThread *thread = nil;
                for(AwfulThread *existing_thread in existing_threads) {
                    if([existing_thread.threadID isEqualToString:tid]) {
                        thread = existing_thread;
                        break;
                    }
                }
                
                [existing_threads removeObjectsInArray:threads];
                
                if(thread == nil) {
                    NSManagedObjectContext *moc = ApplicationDelegate.managedObjectContext;
                    thread = [AwfulThread insertInManagedObjectContext:moc];
                }
                
                thread.threadID = tid;
                thread.isBookmarkedValue = YES;
                
                [AwfulThread populateAwfulThread:thread fromBase:thread_base];
                [threads addObject:thread];
            }
        }
    }
    
    return threads;
}

+(NSMutableArray *)parseThreadsWithData : (NSData *)data forForum : (AwfulForum *)forum
{
    NSString *raw_str = [[NSString alloc] initWithData:data encoding:NSWindowsCP1252StringEncoding];
    NSData *converted = [raw_str dataUsingEncoding:NSUTF8StringEncoding];
    TFHpple *hpple = [[TFHpple alloc] initWithHTMLData:converted];
    
    NSMutableArray *threads = [[NSMutableArray alloc] init];
    NSMutableArray *existing_threads = [NSMutableArray arrayWithArray:[AwfulThread threadsForForum:forum]];
    
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
                AwfulThread *thread = nil;
                for(AwfulThread *existing_thread in existing_threads) {
                    if([existing_thread.threadID isEqualToString:tid]) {
                        thread = existing_thread;
                        break;
                    }
                }
                
                [existing_threads removeObjectsInArray:threads];
                
                if(thread == nil) {
                    NSManagedObjectContext *moc = ApplicationDelegate.managedObjectContext;
                    thread = [AwfulThread insertInManagedObjectContext:moc];
                }
                
                thread.forum = forum;
                thread.threadID = tid;
                thread.isBookmarkedValue = NO;
                
                // will override this with NSNotFound if not stickied from inside 'populateAwfulThread'
                [thread setStickyIndex:[NSNumber numberWithInt:[threads count]]]; 
                
                [AwfulThread populateAwfulThread:thread fromBase:thread_base];
                [threads addObject:thread];
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
    if(sticky == nil) {
        thread.stickyIndexValue = NSNotFound;
    }
    
    TFHppleElement *icon = [thread_base searchForSingle:@"//td[@class='icon']/img"];
    if(icon != nil) {
        NSString *icon_str = [icon objectForKey:@"src"];
        thread.threadIconImageURL = [NSURL URLWithString:icon_str];
    }
    
    TFHppleElement *icon2 = [thread_base searchForSingle:@"//td[@class='icon2']/img"];
    if(icon2 != nil) {
        NSString *icon2_str = [icon2 objectForKey:@"src"];
        thread.threadIconImageURL2 = [NSURL URLWithString:icon2_str];
    }
    
    TFHppleElement *author = [thread_base searchForSingle:@"//td[@class='author']/a"];
    if(author != nil) {
        thread.authorName = [author content];
    }
    
    [thread setSeen:[NSNumber numberWithBool:NO]];
    TFHppleElement *seen = [thread_base searchForSingle:seen_str];
    if(seen != nil) {
        thread.seenValue = YES;
    }
    
    TFHppleElement *locked = [thread_base searchForSingle:closed_str];
    if(locked != nil) {
        thread.isLockedValue = YES;
    }
    
    thread.starCategory = [NSNumber numberWithInt:AwfulStarCategoryNone];
    TFHppleElement *cat_zero = [thread_base searchForSingle:category_zero];
    if(cat_zero != nil) {
        thread.starCategoryValue = AwfulStarCategoryBlue;
    }
    
    TFHppleElement *cat_one = [thread_base searchForSingle:category_one];
    if(cat_one != nil) {
        thread.starCategoryValue = AwfulStarCategoryRed;
    }
    
    TFHppleElement *cat_two = [thread_base searchForSingle:category_two];
    if(cat_two != nil) {
        thread.starCategoryValue = AwfulStarCategoryYellow;
    }
    
    thread.totalUnreadPosts = [NSNumber numberWithInt:-1];
    TFHppleElement *unread = [thread_base searchForSingle:@"//a[@class='count']/b"];
    if(unread != nil) {
        NSString *unread_str = [unread content];
        thread.totalUnreadPostsValue = [unread_str intValue];
    } else {
        unread = [thread_base searchForSingle:@"//a[@class='x']"];
        if(unread != nil) {
            // they've read it all
            thread.totalUnreadPostsValue = 0;
        }
    }
    
    TFHppleElement *total = [thread_base searchForSingle:@"//td[@class='replies']/a"];
    if(total != nil) {
        thread.totalRepliesValue = [[total content] intValue];
    } else {
        total = [thread_base searchForSingle:@"//td[@class='replies']"];
        if(total != nil) {
            thread.totalRepliesValue = [[total content] intValue];
        }
    }
    
    thread.threadRatingValue = NSNotFound;
    TFHppleElement *rating = [thread_base searchForSingle:@"//td[@class='rating']/img"];
    if(rating != nil) {
        NSString *rating_str = [rating objectForKey:@"src"];
        NSURL *rating_url = [NSURL URLWithString:rating_str];
        NSString *last = [rating_url lastPathComponent];
        if([last isEqualToString:@"5stars.gif"]) {
            thread.threadRatingValue = 5;
        } else if([last isEqualToString:@"4stars.gif"]) {
            thread.threadRatingValue = 4;
        } else if([last isEqualToString:@"3stars.gif"]) {
            thread.threadRatingValue = 3;
        } else if([last isEqualToString:@"2stars.gif"]) {
            thread.threadRatingValue = 2;
        } else if([last isEqualToString:@"1stars.gif"]) {
            thread.threadRatingValue = 1;
        } else if([last isEqualToString:@"0stars.gif"]) {
            thread.threadRatingValue = 0;
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

-(NSURL *)firstIconURL
{
    if(self.threadIconImageURL == nil) {
        return nil;
    }
    
    NSString *minus_extension = [[self.threadIconImageURL lastPathComponent] stringByDeletingPathExtension];
    NSURL *tag_url = [[NSBundle mainBundle] URLForResource:minus_extension withExtension:@"png"];
    return tag_url;
}

-(NSURL *)secondIconURL
{
    if(self.threadIconImageURL2 == nil) {
        return nil;
    }
    
    NSString *minus_extension = [[self.threadIconImageURL2 lastPathComponent] stringByDeletingPathExtension];
    NSURL *tag_url = [[NSBundle mainBundle] URLForResource:[minus_extension stringByAppendingString:@"-secondary"] withExtension:@"png"];
    return tag_url;
}

@end
