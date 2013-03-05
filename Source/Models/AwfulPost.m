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
#import "AwfulSettings.h"
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
    return (self.threadIndexValue - 1) / 40 + 1;
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
        existingUsers[post.author.username] = post.author;
        [posts addObject:post];
        if (postInfo.author.originalPoster) {
            thread.author = post.author;
        }
        if (postInfo.beenSeen && thread.seenPostsValue < post.threadIndexValue) {
            thread.seenPostsValue = post.threadIndexValue;
        }
    }
    if (pageInfo.pageNumber == thread.numberOfPagesValue) {
        thread.lastPostAuthorName = [[posts lastObject] author].username;
        thread.lastPostDate = [[posts lastObject] postDate];
    }
    [[AwfulDataStack sharedDataStack] save];
    return posts;
}

+ (NSArray *)postsCreatedOrUpdatedFromJSON:(NSDictionary *)json
{
    NSString *forumID = [json[@"forumid"] stringValue];
    AwfulForum *forum = [AwfulForum firstMatchingPredicate:@"forumID = %@", forumID];
    if (!forum) {
        forum = [AwfulForum insertNew];
        forum.forumID = forumID;
    }
    NSString *threadID = [json[@"thread_info"][@"threadid"] stringValue];
    AwfulThread *thread = [AwfulThread firstOrNewThreadWithThreadID:threadID];
    thread.title = [json[@"thread_info"][@"title"] gtm_stringByUnescapingFromHTML];
    thread.archivedValue = [json[@"archived"] boolValue];
    if (![json[@"thread_icon"] isEqual:[NSNull null]]) {
        thread.threadIconImageURL = [NSURL URLWithString:json[@"thread_icon"][@"iconpath"]];
    }
    thread.forum = forum;
    thread.numberOfPages = json[@"page"][1];
    id seenPosts = json[@"seen_posts"];
    if ([seenPosts isEqual:[NSNull null]]) {
        seenPosts = @0;
    }
    if (seenPosts) {
        thread.seenPosts = seenPosts;
    }
    
    NSArray *postIDs = [json[@"posts"] allKeys];
    NSMutableDictionary *existingPosts = [NSMutableDictionary new];
    for (AwfulPost *post in [AwfulPost fetchAllMatchingPredicate:@"postID IN %@", postIDs]) {
        existingPosts[post.postID] = post;
    }
    for (NSString *postID in json[@"posts"]) {
        NSDictionary *info = json[@"posts"][postID];
        AwfulPost *post = existingPosts[postID] ?: [AwfulPost insertNew];
        post.postID = postID;
        if (![info[@"attachmentid"] isEqual:[NSNull null]] && [info[@"attachmentid"] integerValue]) {
            post.attachmentID = [info[@"attachmentid"] stringValue];
        } else {
            post.attachmentID = nil;
        }
        if (![info[@"editdate"] isEqual:[NSNull null]]) {
            post.editDate = [NSDate dateWithTimeIntervalSince1970:[info[@"editdate"] doubleValue]];
        } else {
            post.editDate = nil;
        }
        if (![info[@"edituserid"] isEqual:[NSNull null]]) {
            NSString *editorUserID = [info[@"edituserid"] stringValue];
            AwfulUser *editor = [AwfulUser firstMatchingPredicate:@"userID = %@", editorUserID];
            if (!editor) {
                editor = [AwfulUser insertNew];
                editor.userID = editorUserID;
            }
            post.editor = editor;
        } else {
            post.editor = nil;
        }
        id message = info[@"message"];
        if ([message respondsToSelector:@selector(stringValue)]) {
            message = [message stringValue];
        }
        post.innerHTML = message;
        post.postDate = [NSDate dateWithTimeIntervalSince1970:[info[@"date"] doubleValue]];
        post.thread = thread;
        post.threadIndex = info[@"post_index"];
        
        NSString *userID = [info[@"userid"] stringValue];
        post.author = [AwfulUser userCreatedOrUpdatedFromJSON:json[@"userids"][userID]];
        if ([info[@"op"] boolValue]) {
            thread.author = post.author;
        }
        
        existingPosts[post.postID] = post;
    }
    NSArray *posts = [[existingPosts allValues]
                      sortedArrayUsingComparator:^NSComparisonResult(AwfulPost *a, AwfulPost *b)
    {
        return [a.threadIndex compare:b.threadIndex];
    }];
    NSNumber *currentPage = json[@"page"][0];
    NSNumber *lastPage = json[@"page"][1];
    if ([currentPage isEqual:lastPage]) {
        AwfulPost *last;
        for (AwfulPost *post in posts) {
            if (!last || last.threadIndexValue < post.threadIndexValue) {
                last = post;
            }
        }
        thread.lastPostAuthorName = last.author.username;
        thread.lastPostDate = last.postDate;
    }
    
    [[AwfulDataStack sharedDataStack] save];
    return posts;
}

- (BOOL)editableByUserWithID:(NSString *)userID
{
    if (!self.thread || self.thread.archivedValue) return NO;
    return [self.author.userID isEqual:userID];
}

@end
