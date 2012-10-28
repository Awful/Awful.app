//
//  AwfulThread.m
//  Awful
//
//  Created by Nolan Waite on 12-05-17.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulThread.h"
#import "AwfulDataStack.h"
#import "AwfulParsing.h"
#import "NSManagedObject+Awful.h"

@implementation AwfulThread

+ (void)removeOldThreadsForForum:(AwfulForum *)forum
{
    [AwfulThread deleteAllMatchingPredicate:@"forum == %@ AND isBookmarked == NO", forum];
}

- (NSString *)firstIconName
{
    NSString *basename = [[self.threadIconImageURL lastPathComponent] stringByDeletingPathExtension];
    return [basename stringByAppendingPathExtension:@"png"];
}

- (NSString *)secondIconName
{
    NSString *basename = [[self.threadIconImageURL2 lastPathComponent] stringByDeletingPathExtension];
    return [basename stringByAppendingPathExtension:@"png"];
}

- (BOOL)canReply
{
    return !(self.isClosedValue || self.isLockedValue);
}

+ (NSSet *)keyPathsForValuesAffectingCanReply
{
    return [NSSet setWithObjects:@"isClosed", @"isLocked", nil];
}

+ (NSArray *)threadsCreatedOrUpdatedWithParsedInfo:(NSArray *)threadInfos
{
    NSMutableArray *threads = [[NSMutableArray alloc] init];
    NSMutableDictionary *existingThreads = [NSMutableDictionary new];
    for (AwfulThread *thread in [self fetchAll]) {
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

#pragma mark - _AwfulThread

- (void)setTotalReplies:(NSNumber *)totalReplies
{
    [self willChangeValueForKey:AwfulThreadAttributes.totalReplies];
    self.primitiveTotalReplies = totalReplies;
    [self didChangeValueForKey:AwfulThreadAttributes.totalReplies];
    self.numberOfPagesValue = 1 + [totalReplies integerValue] / 40;
}

@end
