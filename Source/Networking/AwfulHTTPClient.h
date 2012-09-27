//
//  AwfulHTTPClient.h
//  Awful
//
//  Created by Sean Berry on 5/26/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AFHTTPClient.h"
#import "AwfulPage.h"

@class AwfulForum;
@class AwfulPost;
@class AwfulThread;
@class AwfulPageDataController;
@class AwfulUser;

typedef void (^AwfulErrorBlock)(NSError* error);

static const NSTimeInterval NetworkTimeoutInterval = 5.0;

@interface AwfulHTTPClient : AFHTTPClient

+ (id)sharedClient;

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

-(NSOperation *)replyToThread : (AwfulThread *)thread withText : (NSString *)text onCompletion : (CompletionBlock)completionBlock onError : (AwfulErrorBlock)errorBlock;

-(NSOperation *)editContentsForPost : (AwfulPost *)post onCompletion:(PostContentResponseBlock)postContentResponseBlock onError:(AwfulErrorBlock)errorBlock;

-(NSOperation *)quoteContentsForPost : (AwfulPost *)post onCompletion:(PostContentResponseBlock)postContentResponseBlock onError:(AwfulErrorBlock)errorBlock;

-(NSOperation *)editPost : (AwfulPost *)post withContents : (NSString *)contents onCompletion : (CompletionBlock)completionBlock onError:(AwfulErrorBlock)errorBlock;

-(NSOperation *)submitVote : (int)value forThread : (AwfulThread *)thread onCompletion : (CompletionBlock)completionBlock onError:(AwfulErrorBlock)errorBlock;

-(NSOperation *)processMarkSeenLink : (NSString *)markSeenLink onCompletion : (CompletionBlock)completionBlock onError:(AwfulErrorBlock)errorBlock;

-(NSOperation *)markThreadUnseen : (AwfulThread *)thread onCompletion : (CompletionBlock)completionBlock onError:(AwfulErrorBlock)errorBlock;

@end
