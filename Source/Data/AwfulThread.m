//  AwfulThread.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulThread.h"
#import "AwfulParsing.h"
#import "AwfulSingleUserThreadInfo.h"
#import "AwfulUser.h"
#import "GTMNSString+HTML.h"
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

- (BOOL)beenSeen
{
    return self.seenPostsValue > 0;
}

+ (NSSet *)keyPathsForValuesAffectingBeenSeen
{
    return [NSSet setWithObject:@"seenPosts"];
}

+ (NSArray *)threadsCreatedOrUpdatedWithParsedInfo:(NSArray *)threadInfos
                            inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSMutableDictionary *existingThreads = [NSMutableDictionary new];
    NSArray *threadIDs = [threadInfos valueForKey:@"threadID"];
    for (AwfulThread *thread in [self fetchAllInManagedObjectContext:managedObjectContext
                                                   matchingPredicate:@"threadID IN %@", threadIDs]) {
        existingThreads[thread.threadID] = thread;
    }
    NSMutableDictionary *existingUsers = [NSMutableDictionary new];
    NSArray *usernames = [threadInfos valueForKeyPath:@"author.username"];
    for (AwfulUser *user in [AwfulUser fetchAllInManagedObjectContext:managedObjectContext
                                                    matchingPredicate:@"username IN %@", usernames]) {
        existingUsers[user.username] = user;
    }
    
    for (ThreadParsedInfo *info in threadInfos) {
        if ([info.threadID length] == 0) {
            NSLog(@"ignoring ID-less thread (announcement?)");
            continue;
        }
        AwfulThread *thread = (existingThreads[info.threadID] ?:
                               [AwfulThread insertInManagedObjectContext:managedObjectContext]);
        [info applyToObject:thread];
        if (!thread.author) {
            thread.author = (existingUsers[info.author.username] ?:
                             [AwfulUser insertInManagedObjectContext:managedObjectContext]);
        }
        [info.author applyToObject:thread.author];
        existingUsers[thread.author.username] = thread.author;
        existingThreads[thread.threadID] = thread;
    }
    return [existingThreads allValues];
}

+ (instancetype)firstOrNewThreadWithThreadID:(NSString *)threadID
                      inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    AwfulThread *thread = [self firstInManagedObjectContext:managedObjectContext
                                          matchingPredicate:@"threadID = %@", threadID];
    if (thread) return thread;
    thread = [self insertInManagedObjectContext:managedObjectContext];
    thread.threadID = threadID;
    return thread;
}

- (NSInteger)numberOfPagesForSingleUser:(AwfulUser *)singleUser
{
    return [[AwfulSingleUserThreadInfo firstInManagedObjectContext:self.managedObjectContext
                                                matchingPredicate:@"thread = %@ AND author = %@", self, singleUser]
            numberOfPagesValue];
}

- (void)setNumberOfPages:(NSInteger)numberOfPages forSingleUser:(AwfulUser *)singleUser
{
    AwfulSingleUserThreadInfo *info = [AwfulSingleUserThreadInfo firstInManagedObjectContext:singleUser.managedObjectContext
                                                                           matchingPredicate:@"thread = %@ AND author = %@", self, singleUser];
    if (!info) {
        info = [AwfulSingleUserThreadInfo insertInManagedObjectContext:singleUser.managedObjectContext];
        info.thread = self;
        info.author = singleUser;
    }
    info.numberOfPagesValue = numberOfPages;
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

- (void)setSeenPosts:(NSNumber *)seenPosts
{
    [self willChangeValueForKey:AwfulThreadAttributes.seenPosts];
    self.primitiveSeenPosts = seenPosts;
    [self didChangeValueForKey:AwfulThreadAttributes.seenPosts];
    if (self.seenPostsValue > self.totalRepliesValue + 1) {
        self.totalRepliesValue = self.seenPostsValue - 1;
    }
}

@end
