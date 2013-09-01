//
//  AwfulPost.m
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app
//

#import "AwfulPost.h"
#import "AwfulDataStack.h"
#import "AwfulForum.h"
#import "AwfulParsing.h"
#import "AwfulSettings.h"
#import "AwfulSingleUserThreadInfo.h"
#import "AwfulThread.h"
#import "AwfulUser.h"
#import "GTMNSString+HTML.h"
#import "NSManagedObject+Awful.h"

@implementation AwfulPost

- (BOOL)beenSeen
{
    if (!self.thread || self.threadIndexValue == 0) return NO;
    return self.threadIndexValue <= self.thread.seenPostsValue;
}

+ (NSSet *)keyPathsForValuesAffectingBeenSeen
{
    return [NSSet setWithArray:@[ @"threadIndex", @"thread.seenPosts" ]];
}

- (NSInteger)page
{
    if (self.threadIndexValue == 0) {
        return 0;
    } else {
        return (self.threadIndexValue - 1) / 40 + 1;
    }
}

- (NSInteger)singleUserPage
{
    if (self.singleUserIndexValue == 0) {
        return 0;
    } else {
        return (self.singleUserIndexValue - 1) / 40 + 1;
    }
}

+ (NSArray *)postsCreatedOrUpdatedFromPageInfo:(PageParsedInfo *)pageInfo
{
    if ([pageInfo.forumID length] == 0 || [pageInfo.threadID length] == 0) return nil;
    AwfulForum *forum = [AwfulForum firstMatchingPredicate:@"forumID = %@", pageInfo.forumID];
    if (!forum) {
        forum = [AwfulForum insertNew];
        forum.forumID = pageInfo.forumID;
    }
    forum.name = pageInfo.forumName;
    AwfulThread *thread = [AwfulThread firstOrNewThreadWithThreadID:pageInfo.threadID];
    thread.forum = forum;
    thread.title = pageInfo.threadTitle;
    thread.isBookmarkedValue = pageInfo.threadBookmarked;
    thread.isClosedValue = pageInfo.threadClosed;
    
    NSArray *allPosts = [thread.posts allObjects];
    NSArray *allPostIDs = [allPosts valueForKey:@"postID"];
    NSDictionary *existingPosts = [NSDictionary dictionaryWithObjects:allPosts forKeys:allPostIDs];
    NSArray *allAuthorNames = [pageInfo.posts valueForKeyPath:@"author.username"];
    NSMutableDictionary *existingUsers = [NSMutableDictionary new];
    for (AwfulUser *user in [AwfulUser fetchAllMatchingPredicate:@"username IN %@", allAuthorNames]) {
        existingUsers[user.username] = user;
    }
    NSMutableArray *posts = [NSMutableArray new];
    for (NSUInteger i = 0; i < [pageInfo.posts count]; i++) {
        PostParsedInfo *postInfo = pageInfo.posts[i];
        AwfulPost *post = existingPosts[postInfo.postID];
        if (!post) {
            post = [AwfulPost insertNew];
            post.thread = thread;
        }
        [postInfo applyToObject:post];
        NSInteger threadIndex = 0;
        if ([postInfo.threadIndex length] > 0) {
            threadIndex = [postInfo.threadIndex integerValue];
        } else {
            threadIndex = (pageInfo.pageNumber - 1) * 40 + i + 1;
        }
        if ([pageInfo.singleUserID length] > 0) {
            post.singleUserIndexValue = threadIndex;
        } else {
            post.threadIndexValue = threadIndex;
        }
        if (!post.author) {
            post.author = existingUsers[postInfo.author.username] ?: [AwfulUser insertNew];
        }
        [postInfo.author applyToObject:post.author];
        existingUsers[post.author.username] = post.author;
        [posts addObject:post];
        if (postInfo.author.originalPoster) {
            thread.author = post.author;
        }
        if (postInfo.beenSeen && thread.seenPostsValue < post.threadIndexValue) {
            thread.seenPostsValue = post.threadIndexValue;
        }
    }
    if (pageInfo.singleUserID) {
        AwfulUser *singleUser = [[posts lastObject] author];
        [thread setNumberOfPages:pageInfo.pagesInThread forSingleUser:singleUser];
    } else {
        thread.numberOfPagesValue = pageInfo.pagesInThread;
    }
    if (pageInfo.pageNumber == thread.numberOfPagesValue && !pageInfo.singleUserID) {
        thread.lastPostAuthorName = [[posts lastObject] author].username;
        thread.lastPostDate = [[posts lastObject] postDate];
    }
    [[AwfulDataStack sharedDataStack] save];
    return posts;
}

@end
