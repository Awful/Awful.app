//
//  AwfulPost.m
//  Awful
//
//  Created by Nolan Waite on 12-10-26.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPost.h"
#import "AwfulDataStack.h"
#import "AwfulForum.h"
#import "AwfulParsing.h"
#import "AwfulThread.h"
#import "AwfulUser.h"
#import "NSManagedObject+Awful.h"

@implementation AwfulPost

+ (NSArray *)postsCreatedOrUpdatedFromPageInfo:(PageParsedInfo *)pageInfo
{
    if ([pageInfo.forumID length] == 0 || [pageInfo.threadID length] == 0) return nil;
    AwfulForum *forum = [AwfulForum firstMatchingPredicate:@"forumID = %@", pageInfo.forumID];
    if (!forum) {
        forum = [AwfulForum insertNew];
        forum.forumID = pageInfo.forumID;
    }
    forum.name = pageInfo.forumName;
    AwfulThread *thread = [AwfulThread firstMatchingPredicate:@"threadID = %@", pageInfo.threadID];
    if (!thread) {
        thread = [AwfulThread insertNew];
        thread.threadID = pageInfo.threadID;
    }
    thread.forum = forum;
    thread.title = pageInfo.threadTitle;
    thread.isBookmarkedValue = pageInfo.threadBookmarked;
    thread.isLockedValue = pageInfo.threadLocked;
    thread.numberOfPagesValue = pageInfo.pagesInThread;
    
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
        if ([postInfo.threadIndex length] > 0) {
            post.threadIndexValue = [postInfo.threadIndex integerValue];
        } else {
            post.threadIndexValue = (pageInfo.pageNumber - 1) * 40 + i + 1;
        }
        if (!post.author) {
            post.author = existingUsers[postInfo.author.username] ?: [AwfulUser insertNew];
        }
        [postInfo.author applyToObject:post.author];
        post.author.avatarURL = [postInfo.author.avatarURL absoluteString];
        existingUsers[post.author.username] = post.author;
        [posts addObject:post];
        if (postInfo.author.originalPoster) {
            thread.author = post.author;
        }
    }
    [posts setValue:@(pageInfo.pageNumber) forKey:AwfulPostAttributes.threadPage];
    [[AwfulDataStack sharedDataStack] save];
    return posts;
}

@end
