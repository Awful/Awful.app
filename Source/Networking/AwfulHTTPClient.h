//
//  AwfulHTTPClient.h
//  Awful
//
//  Created by Sean Berry on 5/26/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AFNetworking.h"
#import "AwfulPage.h"
@class AwfulForum;
@class AwfulPost;
@class AwfulThread;
@class AwfulPageDataController;
@class AwfulUser;


typedef void (^AwfulErrorBlock)(NSError* error);


@interface AwfulHTTPClient : AFHTTPClient

+ (AwfulHTTPClient *)sharedClient;

typedef void (^ThreadListResponseBlock)(NSMutableArray *threads);
typedef void (^PageResponseBlock)(AwfulPageDataController *dataController);
typedef void (^UserResponseBlock)(AwfulUser *user);
typedef void (^CompletionBlock)(void);
typedef void (^ForumsListResponseBlock)(NSMutableArray *forums);
typedef void (^PostContentResponseBlock)(NSString *postContent);

-(NSOperation *)threadListForForum:(AwfulForum *)forum pageNum:(NSUInteger)pageNum onCompletion:(ThreadListResponseBlock)threadListResponseBlock onError:(AwfulErrorBlock)errorBlock;

-(NSOperation *)threadListForBookmarksAtPageNum:(NSUInteger)pageNum onCompletion:(ThreadListResponseBlock)threadListResponseBlock onError:(AwfulErrorBlock) errorBlock;

-(NSOperation *)pageDataForThread : (AwfulThread *)thread destinationType : (AwfulPageDestinationType)destinationType pageNum : (NSUInteger)pageNum onCompletion:(PageResponseBlock)pageResponseBlock onError:(AwfulErrorBlock)errorBlock;

-(NSOperation *)userInfoRequestOnCompletion : (UserResponseBlock)userResponseBlock onError : (AwfulErrorBlock)errorBlock;

-(NSOperation *)addBookmarkedThread : (AwfulThread *)thread onCompletion : (CompletionBlock)completionBlock onError : (AwfulErrorBlock)errorBlock;

-(NSOperation *)removeBookmarkedThread : (AwfulThread *)thread onCompletion : (CompletionBlock)completionBlock onError : (AwfulErrorBlock)errorBlock;

-(NSOperation *)forumsListOnCompletion : (ForumsListResponseBlock)forumsListResponseBlock onError : (AwfulErrorBlock)errorBlock;

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

-(NSOperation *)editContentsForPost : (AwfulPost *)post onCompletion:(PostContentResponseBlock)postContentResponseBlock onError:(AwfulErrorBlock)errorBlock;

-(NSOperation *)quoteContentsForPost : (AwfulPost *)post onCompletion:(PostContentResponseBlock)postContentResponseBlock onError:(AwfulErrorBlock)errorBlock;

-(NSOperation *)editPost : (AwfulPost *)post withContents : (NSString *)contents onCompletion : (CompletionBlock)completionBlock onError:(AwfulErrorBlock)errorBlock;

-(NSOperation *)submitVote : (int)value forThread : (AwfulThread *)thread onCompletion : (CompletionBlock)completionBlock onError:(AwfulErrorBlock)errorBlock;

-(NSOperation *)processMarkSeenLink : (NSString *)markSeenLink onCompletion : (CompletionBlock)completionBlock onError:(AwfulErrorBlock)errorBlock;

-(NSOperation *)markThreadUnseen : (AwfulThread *)thread onCompletion : (CompletionBlock)completionBlock onError:(AwfulErrorBlock)errorBlock;

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
