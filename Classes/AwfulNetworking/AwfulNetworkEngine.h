//
//  AwfulNetworkEngine.h
//  Awful
//
//  Created by Sean Berry on 2/22/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "MKNetworkEngine.h"
#import "AwfulPage.h"

@class AwfulForum;
@class AwfulThread;
@class AwfulPageDataController;
@class AwfulUser;

@interface AwfulNetworkEngine : MKNetworkEngine

typedef void (^ThreadListResponseBlock)(NSMutableArray *threads);
typedef void (^PageResponseBlock)(AwfulPageDataController *dataController);
typedef void (^UserResponseBlock)(AwfulUser *user);
typedef void (^CompletionBlock)(void);
typedef void (^ForumsListResponseBlock)(NSMutableArray *forums);

-(MKNetworkOperation *)threadListForForum:(AwfulForum *)forum pageNum:(NSUInteger)pageNum onCompletion:(ThreadListResponseBlock)threadListResponseBlock onError:(MKNKErrorBlock)errorBlock;

-(MKNetworkOperation *)threadListForBookmarksAtPageNum:(NSUInteger)pageNum onCompletion:(ThreadListResponseBlock)threadListResponseBlock onError:(MKNKErrorBlock) errorBlock;

-(MKNetworkOperation *)pageDataForThread : (AwfulThread *)thread destinationType : (AwfulPageDestinationType)destinationType pageNum : (NSUInteger)pageNum onCompletion:(PageResponseBlock)pageResponseBlock onError:(MKNKErrorBlock)errorBlock;

-(MKNetworkOperation *)userInfoRequestOnCompletion : (UserResponseBlock)userResponseBlock onError : (MKNKErrorBlock)errorBlock;

-(MKNetworkOperation *)addBookmarkedThread : (AwfulThread *)thread onCompletion : (CompletionBlock)completionBlock onError : (MKNKErrorBlock)errorBlock;

-(MKNetworkOperation *)removeBookmarkedThread : (AwfulThread *)thread onCompletion : (CompletionBlock)completionBlock onError : (MKNKErrorBlock)errorBlock;

-(MKNetworkOperation *)forumsListOnCompletion : (ForumsListResponseBlock)forumsListResponseBlock onError : (MKNKErrorBlock)errorBlock;

-(MKNetworkOperation *)replyToThread : (AwfulThread *)thread withText : (NSString *)text onCompletion : (CompletionBlock)completionBlock onError : (MKNKErrorBlock)errorBlock;

@end
