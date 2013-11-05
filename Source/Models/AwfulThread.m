//  AwfulThread.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulThread.h"
#import "AwfulParsing.h"
#import "GTMNSString+HTML.h"

@interface AwfulThread ()

@property (strong, nonatomic) NSNumber *primitiveTotalReplies;

@property (strong, nonatomic) NSNumber *primitiveSeenPosts;

@end

@implementation AwfulThread

@dynamic archived;
@dynamic bookmarked;
@dynamic closed;
@dynamic hideFromList;
@dynamic lastPostAuthorName;
@dynamic lastPostDate;
@dynamic numberOfPages;
@dynamic numberOfVotes;
@dynamic rating;
@dynamic secondaryThreadTagURL;
@dynamic seenPosts;
@dynamic starCategory;
@dynamic sticky;
@dynamic stickyIndex;
@dynamic threadID;
@dynamic threadTagURL;
@dynamic title;
@dynamic totalReplies;
@dynamic author;
@dynamic forum;
@dynamic posts;
@dynamic singleUserThreadInfos;
@dynamic primitiveTotalReplies;
@dynamic primitiveSeenPosts;

- (NSString *)firstIconName
{
    return [[self.threadTagURL.lastPathComponent stringByDeletingPathExtension] stringByAppendingPathExtension:@"png"];
}

- (NSString *)secondIconName
{
    NSString *basename = [self.secondaryThreadTagURL.lastPathComponent stringByDeletingPathExtension];
    return [basename stringByAppendingPathExtension:@"png"];
}

- (BOOL)beenSeen
{
    return self.seenPosts > 0;
}

+ (NSSet *)keyPathsForValuesAffectingBeenSeen
{
    return [NSSet setWithObject:@"seenPosts"];
}

+ (instancetype)firstOrNewThreadWithThreadID:(NSString *)threadID
                      inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    AwfulThread *thread = [self fetchArbitraryInManagedObjectContext:managedObjectContext
                                             matchingPredicateFormat:@"threadID = %@", threadID];
    if (thread) return thread;
    thread = [self insertInManagedObjectContext:managedObjectContext];
    thread.threadID = threadID;
    return thread;
}

- (NSInteger)numberOfPagesForSingleUser:(AwfulUser *)singleUser
{
    return [[AwfulSingleUserThreadInfo fetchArbitraryInManagedObjectContext:self.managedObjectContext
                                                    matchingPredicateFormat:@"thread = %@ AND author = %@", self, singleUser]
            numberOfPages];
}

- (void)setNumberOfPages:(NSInteger)numberOfPages forSingleUser:(AwfulUser *)singleUser
{
    AwfulSingleUserThreadInfo *info = [AwfulSingleUserThreadInfo fetchArbitraryInManagedObjectContext:singleUser.managedObjectContext
                                                                              matchingPredicateFormat:@"thread = %@ AND author = %@", self, singleUser];
    if (!info) {
        info = [AwfulSingleUserThreadInfo insertInManagedObjectContext:singleUser.managedObjectContext];
        info.thread = self;
        info.author = singleUser;
    }
    info.numberOfPages = numberOfPages;
}

#pragma mark - _AwfulThread

- (void)setTotalReplies:(int32_t)totalReplies
{
    [self willChangeValueForKey:@"totalReplies"];
    self.primitiveTotalReplies = @(totalReplies);
    [self didChangeValueForKey:@"totalReplies"];
    int32_t minimumNumberOfPages = 1 + totalReplies / 40;
    if (minimumNumberOfPages > self.numberOfPages) {
        self.numberOfPages = minimumNumberOfPages;
    }
}

- (void)setSeenPosts:(int32_t)seenPosts
{
    [self willChangeValueForKey:@"seenPosts"];
    self.primitiveSeenPosts = @(seenPosts);
    [self didChangeValueForKey:@"seenPosts"];
    if (self.seenPosts > self.totalReplies + 1) {
        self.totalReplies = self.seenPosts - 1;
    }
}

@end
