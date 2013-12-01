//  AwfulPost.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPost.h"

@implementation AwfulPost

@dynamic attachmentID;
@dynamic editable;
@dynamic editDate;
@dynamic innerHTML;
@dynamic postDate;
@dynamic postID;
@dynamic singleUserIndex;
@dynamic threadIndex;
@dynamic author;
@dynamic editor;
@dynamic thread;

- (BOOL)beenSeen
{
    if (!self.thread || self.threadIndex == 0) return NO;
    return self.threadIndex <= self.thread.seenPosts;
}

+ (NSSet *)keyPathsForValuesAffectingBeenSeen
{
    return [NSSet setWithArray:@[ @"threadIndex", @"thread.seenPosts" ]];
}

- (NSInteger)page
{
    if (self.threadIndex == 0) {
        return 0;
    } else {
        return (self.threadIndex - 1) / 40 + 1;
    }
}

- (NSInteger)singleUserPage
{
    if (self.singleUserIndex == 0) {
        return 0;
    } else {
        return (self.singleUserIndex - 1) / 40 + 1;
    }
}

+ (instancetype)firstOrNewPostWithPostID:(NSString *)postID
                  inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSParameterAssert(postID.length > 0);
    AwfulPost *post = [self fetchArbitraryInManagedObjectContext:managedObjectContext
                                         matchingPredicateFormat:@"postID = %@", postID];
    if (!post) {
        post = [self insertInManagedObjectContext:managedObjectContext];
        post.postID = postID;
    }
    return post;
}

@end
