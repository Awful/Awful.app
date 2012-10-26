//
//  AwfulHTTPClient.h
//  Awful
//
//  Created by Sean Berry on 5/26/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AFNetworking.h"
@class PageParsedInfo;

@interface AwfulHTTPClient : AFHTTPClient

// Singleton instance.
+ (AwfulHTTPClient *)client;

// Gets the threads in a forum on a given page.
//
// forumID  - The ID of the forum with the threads.
// page     - Which page to get.
// callback - A block to call after listing the threads, which takes as parameters:
//              error   - An error on failure, or nil on success.
//              threads - A list of AwfulThread on success, or nil on failure.
//
// Returns the enqueued network operation.
- (NSOperation *)listThreadsInForumWithID:(NSString *)forumID
                                   onPage:(NSInteger)page
                                  andThen:(void (^)(NSError *error, NSArray *threads))callback;

// Gets the bookmarked threads on a given page.
//
// page     - Which page to get.
// callback - A block to call after listing the threads, which takes as parameters:
//              error   - An error on failure, or nil on success.
//              threads - A list of AwfulThread on success, or nil on failure.
//
// Returns the enqueued network operation.
- (NSOperation *)listBookmarkedThreadsOnPage:(NSInteger)page
                                     andThen:(void (^)(NSError *error, NSArray *threads))callback;

// Gets the posts in a thread on a given page.
//
// threadID - Which thread to list.
// page     - Which page to get. First page is 1; AwfulPageNextUnread and AwfulPageLast are also
//            available.
// callback - A block to call after listing the posts, which takes as parameters:
//              error    - An error on failure, or nil on success.
//              pageInfo - The posts and other information gleaned from the page.
//
// Returns the enqueued network operation.
- (NSOperation *)listPostsInThreadWithID:(NSString *)threadID
    onPage:(NSInteger)page
    andThen:(void (^)(NSError *error, PageParsedInfo *pageInfo))callback;

enum {
    AwfulPageNextUnread = -1,
    AwfulPageLast = -2
};

// Get the logged-in user's name and ID.
//
// callback - A block to call after getting the user's info, which takes as parameters:
//              error    - An error on failure, or nil on success.
//              userInfo - A dictionary with keys "userID", "username" on success, or nil on
//                         failure.
//
// Returns the enqueued network operation.
- (NSOperation *)learnUserInfoAndThen:(void (^)(NSError *error, NSDictionary *userInfo))callback;

// Add a thread to the user's bookmarks.
//
// threadID - The ID of the thread to add.
// callback - A block to call after adding the thread, which takes as parameters:
//              error - An error on failure, or nil on success.
//
// Returns the enqueued network operation.
- (NSOperation *)bookmarkThreadWithID:(NSString *)threadID
                              andThen:(void (^)(NSError *error))callback;

// Remove a thread from the user's bookmarks.
//
// threadID - The ID of the thread to add.
// callback - A block to call after removing the thread, which takes as parameters:
//              error - An error on failure, or nil on success.
//
// Returns the enqueued network operation.
- (NSOperation *)unbookmarkThreadWithID:(NSString *)threadID
                                andThen:(void (^)(NSError *error))callback;

// Get the forum hierarchy.
//
// callback - A block to call after updating all forums and subforums, which takes as parameters:
//              error  - An error on failure, or nil on succes.
//              forums - A list of AwfulForum on success, or nil on failure.
//
// Returns the enqueued network operation.
- (NSOperation *)listForumsAndThen:(void (^)(NSError *error, NSArray *forums))callback;

// Posts a new reply to a thread.
//
// threadID - The ID of the thread to reply to.
// text     - The bbcode-formatted reply.
// callback - A block to call after sending the reply, which takes as parameters:
//              error  - An error on failure, or nil on success.
//              postID - The ID of the new post, or nil if it's the last post in the thread.
//
// Returns the enqueued network operation.
- (NSOperation *)replyToThreadWithID:(NSString *)threadID
                                text:(NSString *)text
                             andThen:(void (^)(NSError *error, NSString *postID))callback;

// Get the text of a post, for editing.
//
// postID   - The ID of the post.
// callback - A block to call after getting the text of the post, which takes as parameters:
//              error - An error on failure, or nil on success.
//              text  - The text content of the post, or nil on failure.
//
// Returns the enqueued network operation.
- (NSOperation *)getTextOfPostWithID:(NSString *)postID
                             andThen:(void (^)(NSError *error, NSString *text))callback;

// Get the text of a post, for quoting.
//
// postID - The ID of the post.
// callback - A block to call after getting the quoted text of the post, which takes as parameters:
//              error      - An error on failure, or nil on success.
//              quotedText - The quoted text content of the post, or nil on failure.
//
// Returns the enqueued network operation.
- (NSOperation *)quoteTextOfPostWithID:(NSString *)postID
                               andThen:(void (^)(NSError *error, NSString *quotedText))callback;

// Edit a post's content.
//
// postID - The post to edit.
// text   - The new content for the post.
// callback - A block to call after editing the post, which takes as parameters:
//              error - An error on failure, or nil on success.
//
// Returns the enqueued network operation.
- (NSOperation *)editPostWithID:(NSString *)postID
                           text:(NSString *)text
                        andThen:(void (^)(NSError *error))callback;

// Rate a thread.
//
// threadID - Which thread to rate.
// rating   - A rating from 1 to 5, inclusive.
// callback - A block to call after voting, which takes as parameters:
//              error - An error on failure, or nil on success.
//
// Returns the enqueued network operation.
- (NSOperation *)rateThreadWithID:(NSString *)threadID
                           rating:(NSInteger)rating
                          andThen:(void (^)(NSError *error))callback;

// Mark a thread as read up to a point.
//
// threadID - Which thread to mark.
// index    - How many posts to mark as read.
// callback - A block to call after marking, which takes as parameters:
//              error - An error on failure, or nil on success.
//
// Returns the enqueued network operation.
- (NSOperation *)markThreadWithID:(NSString *)threadID
              readUpToPostAtIndex:(NSString *)index
                          andThen:(void (^)(NSError *error))callback;

// Mark an entire thread as unread.
//
// threadID - Which thread to mark.
// callback - A block to call after marking, which takes as parameters:
//              error - An error on failure, or nil on success.
//
// Returns the enqueued network operation.
- (NSOperation *)forgetReadPostsInThreadWithID:(NSString *)threadID
                                       andThen:(void (^)(NSError *error))callback;

// Logs in to the Forums, setting a cookie for future requests.
//
// username - Who to log in as.
// password - Their password.
// callback - A block to call after logging in, which takes as parameters:
//              error - An error on failure, or nil on success.
//
// Returns the enqueued network operation.
- (NSOperation *)logInAsUsername:(NSString *)username
                    withPassword:(NSString *)password
                         andThen:(void (^)(NSError *error))callback;

// Finds the thread and page where a post appears.
//
// postID   - The ID of the post to locate.
// callback - A block to call after locating the post, which takes as parameters:
//              error    - An error on failure, or nil on success.
//              threadID - The ID of the thread containing the post, or nil on failure.
//              page     - The page number where the post appears, or NSIntegerMax if the post
//                         appears on the last page, or 0 on failure.
//
// Returns the enqueued network operation.
- (NSOperation *)locatePostWithID:(NSString *)postID
    andThen:(void (^)(NSError *error, NSString *threadID, NSInteger page))callback;

@end
