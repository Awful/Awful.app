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
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [[NSThread currentThread] setName:@"com.awfulapp.awful.posts.update"];
        
        NSManagedObjectContext *moc = [AwfulDataStack sharedDataStack].newThreadContext;
        
        if ([pageInfo.forumID length] == 0 || [pageInfo.threadID length] == 0) return;
        AwfulForum *forum = [AwfulForum firstWithManagedObjectContext:moc
                                                    matchingPredicate:@"forumID = %@", pageInfo.forumID];
        if (!forum) {
            forum = [AwfulForum insertInManagedObjectContext:moc];
            forum.forumID = pageInfo.forumID;
        }
        forum.name = pageInfo.forumName;
        AwfulThread *thread = [AwfulThread firstWithManagedObjectContext:moc
                                                       matchingPredicate:@"threadID = %@", pageInfo.threadID];
        if (!thread) {
            thread = [AwfulThread insertInManagedObjectContext:moc];
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
        for (AwfulUser *user in [AwfulUser fetchAllWithManagedObjectContext:moc
                                                          matchingPredicate:@"username IN %@", allAuthorNames]) {
            existingUsers[user.username] = user;
        }
        NSMutableArray *posts = [NSMutableArray new];
        for (NSUInteger i = 0; i < [pageInfo.posts count]; i++) {
            PostParsedInfo *postInfo = pageInfo.posts[i];
            AwfulPost *post = existingPosts[postInfo.postID];
            if (!post) {
                post = [AwfulPost insertInManagedObjectContext:moc];
                post.thread = thread;
            }
            [postInfo applyToObject:post];
            if ([postInfo.threadIndex length] > 0) {
                post.threadIndexValue = [postInfo.threadIndex integerValue];
            } else {
                post.threadIndexValue = (pageInfo.pageNumber - 1) * 40 + i + 1;
            }
            if (!post.author) {
                post.author = existingUsers[postInfo.author.username] ?:
                                        [AwfulUser insertInManagedObjectContext:moc];
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
        [moc save:nil];
        
        return;
    });
    return nil;
}

@end
