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
#import "NSManagedObject+Awful.h"

@implementation AwfulPost

+ (NSArray *)postsCreatedOrUpdatedFromPageInfo:(PageParsedInfo *)pageInfo
{
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
    
    NSArray *allPosts = [thread.posts allObjects];
    NSArray *allPostIDs = [allPosts valueForKey:@"postID"];
    NSDictionary *existingPosts = [NSDictionary dictionaryWithObjects:allPosts forKeys:allPostIDs];
    NSMutableArray *posts = [NSMutableArray new];
    for (PostParsedInfo *postInfo in pageInfo.posts) {
        AwfulPost *post = existingPosts[postInfo.postID];
        if (!post) {
            post = [AwfulPost insertNew];
            post.thread = thread;
        }
        [postInfo applyToObject:post];
        post.threadIndexValue = [postInfo.threadIndex integerValue];
        post.authorAvatarURL = [postInfo.authorAvatarURL absoluteString];
        [posts addObject:post];
    }
    [posts setValue:@(pageInfo.pageNumber) forKey:AwfulPostAttributes.threadPage];
    [[AwfulDataStack sharedDataStack] save];
    return posts;
}

@end
