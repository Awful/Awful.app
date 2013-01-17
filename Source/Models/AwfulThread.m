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
#import "AwfulUser.h"
#import "NSManagedObject+Awful.h"

@implementation AwfulThread

- (NSString *)firstIconName
{
    NSString *basename = [[self.threadIconImageURL lastPathComponent]
                          stringByDeletingPathExtension];
    return [basename stringByAppendingPathExtension:@"png"];
}

- (NSString *)secondIconName
{
    NSString *basename = [[self.threadIconImageURL2 lastPathComponent]
                          stringByDeletingPathExtension];
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
    NSMutableDictionary *existingThreads = [NSMutableDictionary new];
    NSArray *threadIDs = [threadInfos valueForKey:@"threadID"];
    for (AwfulThread *thread in [self fetchAllMatchingPredicate:@"threadID IN %@", threadIDs]) {
        existingThreads[thread.threadID] = thread;
    }
    NSMutableDictionary *existingUsers = [NSMutableDictionary new];
    NSArray *usernames = [threadInfos valueForKeyPath:@"author.username"];
    for (AwfulUser *user in [AwfulUser fetchAllMatchingPredicate:@"username IN %@", usernames]) {
        existingUsers[user.username] = user;
    }
    
    for (ThreadParsedInfo *info in threadInfos) {
        if ([info.threadID length] == 0) {
            NSLog(@"ignoring ID-less thread (announcement?)");
            continue;
        }
        AwfulThread *thread = existingThreads[info.threadID] ?: [AwfulThread insertNew];
        [info applyToObject:thread];
        if (!thread.author) thread.author = [AwfulUser insertNew];
        [info.author applyToObject:thread.author];
        existingUsers[thread.author.username] = thread.author;
        existingThreads[thread.threadID] = thread;
    }
    [[AwfulDataStack sharedDataStack] save];
    return [existingThreads allValues];
}

#pragma mark - _AwfulThread

- (void)setTotalReplies:(NSNumber *)totalReplies
{
    [self willChangeValueForKey:AwfulThreadAttributes.totalReplies];
    self.primitiveTotalReplies = totalReplies;
    [self didChangeValueForKey:AwfulThreadAttributes.totalReplies];
    NSInteger minimumNumberOfPages = 1 + [totalReplies integerValue] / 40;
    if (minimumNumberOfPages > self.numberOfPagesValue) {
        self.numberOfPagesValue = minimumNumberOfPages;
    }
}

@end
