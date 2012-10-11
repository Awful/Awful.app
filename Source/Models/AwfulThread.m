//
//  AwfulThread.m
//  Awful
//
//  Created by Nolan Waite on 12-05-17.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulThread.h"

@implementation AwfulThread

+ (void)removeOldThreadsForForum:(AwfulForum *)forum
{
    [AwfulThread deleteAllMatchingPredicate:@"forum == %@ AND isBookmarked == NO", forum];
}

+ (NSArray *)bookmarkedThreads
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:[AwfulThread entityName]];
    NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"lastPostDate" ascending:NO];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"isBookmarked==YES"];
    [fetchRequest setSortDescriptors:[NSArray arrayWithObject:sort]];
    [fetchRequest setPredicate:predicate];
    
    NSError *error = nil;
    NSArray *threads = [[AwfulDataStack sharedDataStack].context executeFetchRequest:fetchRequest
                                                                               error:&error];
    if (!threads) {
        NSLog(@"failed to load threads %@", error);
        return nil;
    }
    return threads;
}

+ (void)removeBookmarkedThreads
{
    NSArray *threads = [AwfulThread bookmarkedThreads];
    for(AwfulThread *thread in threads) {
        [thread.managedObjectContext deleteObject:thread];
    }
}

- (NSURL *)firstIconURL
{
    if(self.threadIconImageURL == nil) {
        return nil;
    }
    
    NSString *minus_extension = [[self.threadIconImageURL lastPathComponent] stringByDeletingPathExtension];
    NSURL *tag_url = [[NSBundle mainBundle] URLForResource:minus_extension withExtension:@"png"];
    return tag_url;
}

- (NSURL *)secondIconURL
{
    if(self.threadIconImageURL2 == nil) {
        return nil;
    }
    
    NSString *minus_extension = [[self.threadIconImageURL2 lastPathComponent] stringByDeletingPathExtension];
    NSURL *tag_url = [[NSBundle mainBundle] URLForResource:[minus_extension stringByAppendingString:@"-secondary"] withExtension:@"png"];
    return tag_url;
}

+ (NSArray *)threadsCreatedOrUpdatedWithParsedInfo:(NSArray *)threadInfos
{
    NSMutableArray *threads = [[NSMutableArray alloc] init];
    NSMutableDictionary *existingThreads = [NSMutableDictionary new];
    for (AwfulThread *thread in [self bookmarkedThreads]) {
        existingThreads[thread.threadID] = thread;
    }
    
    for (ThreadParsedInfo *info in threadInfos) {
        if ([info.threadID length] == 0) {
            NSLog(@"ignoring ID-less thread");
            continue;
        }
        AwfulThread *thread = existingThreads[info.threadID];
        if (!thread) {
            thread = [AwfulThread insertInManagedObjectContext:[AwfulDataStack sharedDataStack].context];
        }
        [info applyToObject:thread];
        [threads addObject:thread];
    }
    [[AwfulDataStack sharedDataStack] save];
    return threads;
}

@end


NSString * const AwfulThreadDidUpdateNotification = @"Thread did update notification";
