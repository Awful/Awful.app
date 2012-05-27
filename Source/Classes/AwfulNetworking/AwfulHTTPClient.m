//
//  AwfulHTTPClient.m
//  Awful
//
//  Created by Sean Berry on 5/26/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulHTTPClient.h"
#import "NetworkingFileLogger.h"

@implementation AwfulHTTPClient

+ (id)sharedClient {
    static AwfulHTTPClient *__sharedClient;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __sharedClient = [[AwfulHTTPClient alloc] initWithBaseURL:
                            [NSURL URLWithString:@"http://forums.somethingawful.com/"]];
    });
    
    return __sharedClient;
}

+ (DDFileLogger *)logger
{
    static DDFileLogger *logger = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        logger = [[NetworkingFileLogger alloc] init];
        [DDLog addLogger:logger];
    });
    return logger;
}

-(NSOperation *)threadListForForum:(AwfulForum *)forum pageNum:(NSUInteger)pageNum onCompletion:(ThreadListResponseBlock)threadListResponseBlock onError:(AwfulErrorBlock)errorBlock
{
    return nil;
}

-(NSOperation *)threadListForBookmarksAtPageNum:(NSUInteger)pageNum onCompletion:(ThreadListResponseBlock)threadListResponseBlock onError:(AwfulErrorBlock) errorBlock
{
    return nil;
}

-(NSOperation *)pageDataForThread : (AwfulThread *)thread destinationType : (AwfulPageDestinationType)destinationType pageNum : (NSUInteger)pageNum onCompletion:(PageResponseBlock)pageResponseBlock onError:(AwfulErrorBlock)errorBlock
{
    return nil;
}

-(NSOperation *)userInfoRequestOnCompletion : (UserResponseBlock)userResponseBlock onError : (AwfulErrorBlock)errorBlock
{
    return nil;
}

-(NSOperation *)addBookmarkedThread : (AwfulThread *)thread onCompletion : (CompletionBlock)completionBlock onError : (AwfulErrorBlock)errorBlock
{
    return nil;
}

-(NSOperation *)removeBookmarkedThread : (AwfulThread *)thread onCompletion : (CompletionBlock)completionBlock onError : (AwfulErrorBlock)errorBlock
{
    return nil;
}

-(NSOperation *)forumsListOnCompletion : (ForumsListResponseBlock)forumsListResponseBlock onError : (AwfulErrorBlock)errorBlock
{
    return nil;
}

-(NSOperation *)replyToThread : (AwfulThread *)thread withText : (NSString *)text onCompletion : (CompletionBlock)completionBlock onError : (AwfulErrorBlock)errorBlock
{
    return nil;
}

-(NSOperation *)editContentsForPost : (AwfulPost *)post onCompletion:(PostContentResponseBlock)postContentResponseBlock onError:(AwfulErrorBlock)errorBlock
{
    return nil;
}

-(NSOperation *)quoteContentsForPost : (AwfulPost *)post onCompletion:(PostContentResponseBlock)postContentResponseBlock onError:(AwfulErrorBlock)errorBlock
{
    return nil;
}

-(NSOperation *)editPost : (AwfulPost *)post withContents : (NSString *)contents onCompletion : (CompletionBlock)completionBlock onError:(AwfulErrorBlock)errorBlock
{
    return nil;
}

-(NSOperation *)submitVote : (int)value forThread : (AwfulThread *)thread onCompletion : (CompletionBlock)completionBlock onError:(AwfulErrorBlock)errorBlock
{
    return nil;
}

-(NSOperation *)processMarkSeenLink : (NSString *)markSeenLink onCompletion : (CompletionBlock)completionBlock onError:(AwfulErrorBlock)errorBlock
{
    return nil;
}

-(NSOperation *)markThreadUnseen : (AwfulThread *)thread onCompletion : (CompletionBlock)completionBlock onError:(AwfulErrorBlock)errorBlock
{
    return nil;
}

@end
