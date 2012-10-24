//
//  AwfulHTTPClient.m
//  Awful
//
//  Created by Sean Berry on 5/26/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulHTTPClient.h"
#import "AwfulDataStack.h"
#import "AwfulModels.h"
#import "AwfulPage.h"
#import "AwfulPageDataController.h"
#import "AwfulPageTemplate.h"
#import "AwfulParsing.h"
#import "AwfulSettings.h"
#import "AwfulStringEncoding.h"

@implementation AwfulHTTPClient

+ (AwfulHTTPClient *)sharedClient
{
    static AwfulHTTPClient *sharedClient;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedClient = [[AwfulHTTPClient alloc] initWithBaseURL:
                        [NSURL URLWithString:@"http://forums.somethingawful.com/"]];
        [[AFNetworkActivityIndicatorManager sharedManager] setEnabled:YES];
    });
    return sharedClient;
}

- (id)initWithBaseURL:(NSURL *)url
{
    self = [super initWithBaseURL:url];
    if (self) {
        self.stringEncoding = NSWindowsCP1252StringEncoding;
    }
    return self;
}

- (NSOperation *)threadListForForum:(AwfulForum *)forum
                            pageNum:(NSUInteger)pageNum
                       onCompletion:(ThreadListResponseBlock)threadListResponseBlock
                            onError:(AwfulErrorBlock)errorBlock
{
    NSString *path = [NSString stringWithFormat:@"forumdisplay.php?forumid=%@&perpage=40&pagenumber=%u", forum.forumID, pageNum];
    NSMutableURLRequest *urlRequest = [self requestWithMethod:@"GET" path:path parameters:nil];
    urlRequest.timeoutInterval = 5.0;
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest 
                                                               success:^(id _, id response)
    {
        if (pageNum == 1) {
            [forum deleteUnbookmarkedThreads];
        }
        NSData *data = (NSData *)response;
        NSArray *threadInfos = [ThreadParsedInfo threadsWithHTMLData:data];
        NSArray *threads = [AwfulThread threadsCreatedOrUpdatedWithParsedInfo:threadInfos];
        // Assumes less than one page (40 threads' worth) of stickied threads.
        NSInteger stickyIndex = -(NSInteger)[threads count];
        for (AwfulThread *thread in threads) {
            thread.forum = forum;
            thread.stickyIndexValue = thread.isStickyValue ? stickyIndex++ : 0;
        }
        [[AwfulDataStack sharedDataStack] save];
        threadListResponseBlock([threads mutableCopy]);
    } failure:^(id _, NSError *error)
    {
        errorBlock(error);
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

- (NSOperation *)threadListForBookmarksAtPageNum:(NSUInteger)pageNum onCompletion:(ThreadListResponseBlock)threadListResponseBlock onError:(AwfulErrorBlock) errorBlock
{
    NSString *path = [NSString stringWithFormat:@"bookmarkthreads.php?action=view&perpage=40&pagenumber=%d", pageNum];
    NSURLRequest *urlRequest = [self requestWithMethod:@"GET" path:path parameters:nil];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest 
                                                               success:^(id _, id response)
    {
        if (pageNum == 1) {
            [AwfulThread removeBookmarkedThreads];
        }
        NSData *data = (NSData *)response;
        NSArray *threadInfos = [ThreadParsedInfo threadsWithHTMLData:data];
        NSArray *threads = [AwfulThread threadsCreatedOrUpdatedWithParsedInfo:threadInfos];
        for (AwfulThread *thread in threads) {
            thread.isBookmarkedValue = YES;
        }
        [[AwfulDataStack sharedDataStack] save];
        threadListResponseBlock([threads mutableCopy]);
    } failure:^(id _, NSError *error)
    {
        errorBlock(error);
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

-(NSOperation *)pageDataForThread : (AwfulThread *)thread destinationType : (AwfulPageDestinationType)destinationType pageNum : (NSUInteger)pageNum onCompletion:(PageResponseBlock)pageResponseBlock onError:(AwfulErrorBlock)errorBlock
{
    NSString *append = @"";
    switch(destinationType) {
        case AwfulPageDestinationTypeFirst:
            append = @"";
            break;
        case AwfulPageDestinationTypeLast:
            append = @"&goto=lastpost";
            break;
        case AwfulPageDestinationTypeNewpost:
            append = @"&goto=newpost";
            break;
        case AwfulPageDestinationTypeSpecific:
            append = [NSString stringWithFormat:@"&pagenumber=%d", pageNum];
            break;
        default:
            append = @"";
            break;
    }
    
    NSString *path = [[NSString alloc] initWithFormat:@"showthread.php?threadid=%@%@", thread.threadID, append];
    NSURLRequest *urlRequest = [self requestWithMethod:@"GET" path:path parameters:nil];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest 
       success:^(AFHTTPRequestOperation *operation, id response) {
           NSURLResponse *urlResponse = [operation response];
           NSURL *lastURL = [urlResponse URL];
           NSData *data = (NSData *)response;
           AwfulPageDataController *data_controller = [[AwfulPageDataController alloc] initWithResponseData:data pageURL:lastURL];
           thread.isLockedValue = data_controller.isLocked;
           pageResponseBlock(data_controller);
       } 
       failure:^(AFHTTPRequestOperation *operation, NSError *error) {
           errorBlock(error);
       }];
    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}

- (NSOperation *)userInfoRequestOnCompletion:(UserResponseBlock)userResponseBlock
                                     onError:(AwfulErrorBlock)errorBlock
{
    NSString *path = @"member.php?action=editprofile";
    NSURLRequest *urlRequest = [self requestWithMethod:@"GET" path:path parameters:nil];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest 
                                                               success:^(id _, id response)
    {
        AwfulUser *user = AwfulSettings.settings.currentUser;
        if (!user) {
            errorBlock(nil);
            return;
        }
        UserParsedInfo *parsed = [[UserParsedInfo alloc] initWithHTMLData:(NSData *)response];
        [parsed applyToObject:user];
        AwfulSettings.settings.currentUser = user;
        userResponseBlock(user);
    } failure:^(AFHTTPRequestOperation *_, NSError *error)
    {
        errorBlock(error);
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

typedef enum BookmarkAction {
    AddBookmark,
    RemoveBookmark,
} BookmarkAction;

- (NSOperation *)modifyBookmark:(BookmarkAction)action withThread:(AwfulThread *)thread onCompletion:(CompletionBlock)completionBlock onError:(AwfulErrorBlock)errorBlock
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:@"1" forKey:@"json"];
    [dict setObject:(action == AddBookmark ? @"add" : @"remove") forKey:@"action"];
    [dict setObject:thread.threadID forKey:@"threadid"];
    NSString *path = @"bookmarkthreads.php";
    NSURLRequest *urlRequest = [self requestWithMethod:@"POST" path:path parameters:dict];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest 
       success:^(AFHTTPRequestOperation *operation, id response) {
           if (completionBlock) completionBlock();
       } 
       failure:^(AFHTTPRequestOperation *operation, NSError *error) {
           if (errorBlock) errorBlock(error);
       }];
    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}

-(NSOperation *)addBookmarkedThread : (AwfulThread *)thread onCompletion : (CompletionBlock)completionBlock onError : (AwfulErrorBlock)errorBlock
{
    return [self modifyBookmark:AddBookmark withThread:thread onCompletion:completionBlock onError:errorBlock];
}

-(NSOperation *)removeBookmarkedThread : (AwfulThread *)thread onCompletion : (CompletionBlock)completionBlock onError : (AwfulErrorBlock)errorBlock
{
    return [self modifyBookmark:RemoveBookmark withThread:thread onCompletion:completionBlock onError:errorBlock];
}

- (NSOperation *)forumsListOnCompletion:(ForumsListResponseBlock)forumsListResponseBlock
                                onError:(AwfulErrorBlock)errorBlock
{
    // Seems like only forumdisplay.php and showthread.php have the <select> with a complete list
    // of forums. We'll use the Comedy Goldmine as it's generally available and hopefully it's not
    // much of a burden since threads rarely get goldmined.
    NSString *path = @"forumdisplay.php?forumid=21";
    NSURLRequest *urlRequest = [self requestWithMethod:@"GET" path:path parameters:nil];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest
                                                               success:^(id _, id response)
    {
        NSData *data = (NSData *)response;
        ForumHierarchyParsedInfo *info = [[ForumHierarchyParsedInfo alloc] initWithHTMLData:data];
        NSArray *forums = [AwfulForum updateCategoriesAndForums:info];
        if (forumsListResponseBlock) forumsListResponseBlock([forums mutableCopy]);
    } failure:^(id _, NSError *error)
    {
        if (errorBlock) errorBlock(error);
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

- (NSOperation *)replyToThreadWithID:(NSString *)threadID
                                text:(NSString *)text
                             andThen:(void (^)(NSError *error, NSString *postID))callback
{
    NSDictionary *parameters = @{ @"action" : @"newreply", @"threadid" : threadID };
    NSURLRequest *urlRequest = [self requestWithMethod:@"GET"
                                                  path:@"newreply.php"
                                            parameters:parameters];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest
                                                               success:^(id _, id data)
    {
        ReplyFormParsedInfo *formInfo = [[ReplyFormParsedInfo alloc] initWithHTMLData:(NSData *)data];
        if (!(formInfo.formkey && formInfo.formCookie)) {
            NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : @"Thread is closed" };
            NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain code:-1 userInfo:userInfo];
            if (callback) callback(error, nil);
            return;
        }
        NSMutableDictionary *postParameters = [@{
            @"threadid" : threadID,
            @"formkey" : formInfo.formkey,
            @"form_cookie" : formInfo.formCookie,
            @"action" : @"postreply",
            @"message" : text,
            @"parseurl" : @"yes",
            @"submit" : @"Submit Reply",
        } mutableCopy];
        if (formInfo.bookmark) {
            postParameters[@"bookmark"] = formInfo.bookmark;
        }
        
        NSURLRequest *postRequest = [self requestWithMethod:@"POST"
                                                       path:@"newreply.php"
                                                 parameters:postParameters];
        [self enqueueHTTPRequestOperation:[self HTTPRequestOperationWithRequest:postRequest
                                                                        success:^(id _, id responseData)
        {
            SuccessfulReplyInfo *replyInfo = [[SuccessfulReplyInfo alloc] initWithHTMLData:(NSData *)responseData];
            if (callback) callback(nil, replyInfo.lastPage ? nil : replyInfo.postID);
        } failure:^(id _, NSError *error)
        {
            if (callback) callback(error, nil);
        }]];
    } failure:^(id _, NSError *error)
    {
        if (callback) callback(error, nil);
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

typedef enum PostContentType {
    EditPostContent,
    QuotePostContent,
} PostContentType;

-(NSOperation *)contentsForPost : (AwfulPost *)post postType : (PostContentType)postType onCompletion:(PostContentResponseBlock)postContentResponseBlock onError:(AwfulErrorBlock)errorBlock
{
    NSString *path;
    if(postType == EditPostContent) {
        path = [NSString stringWithFormat:@"editpost.php?action=editpost&postid=%@", post.postID];
    } else if(postType == QuotePostContent) {
        path = [NSString stringWithFormat:@"newreply.php?action=newreply&postid=%@", post.postID];
    } else {
        return nil;
    }
    
    NSURLRequest *urlRequest = [self requestWithMethod:@"GET" path:path parameters:nil];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest 
       success:^(AFHTTPRequestOperation *operation, id response) {
           NSData *data = (NSData *)response;
           NSString *rawString = [[NSString alloc] initWithData:data encoding:self.stringEncoding];
           NSData *converted = [rawString dataUsingEncoding:NSUTF8StringEncoding];
           TFHpple *base = [[TFHpple alloc] initWithHTMLData:converted];
           
           TFHppleElement *quoteElement = [base searchForSingle:@"//textarea[@name='message']"];
           postContentResponseBlock([quoteElement content]);
       } 
       failure:^(AFHTTPRequestOperation *operation, NSError *error) {
           errorBlock(error);
       }];
    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}

-(NSOperation *)editContentsForPost : (AwfulPost *)post onCompletion:(PostContentResponseBlock)postContentResponseBlock onError:(AwfulErrorBlock)errorBlock
{
    return [self contentsForPost:post postType:EditPostContent onCompletion:postContentResponseBlock onError:errorBlock];
}

-(NSOperation *)quoteContentsForPost : (AwfulPost *)post onCompletion:(PostContentResponseBlock)postContentResponseBlock onError:(AwfulErrorBlock)errorBlock
{
    return [self contentsForPost:post postType:QuotePostContent onCompletion:postContentResponseBlock onError:errorBlock];
}

-(NSOperation *)editPost : (AwfulPost *)post withContents : (NSString *)contents onCompletion : (CompletionBlock)completionBlock onError:(AwfulErrorBlock)errorBlock
{
    NSString *path = [NSString stringWithFormat:@"editpost.php?action=editpost&postid=%@", post.postID];
    NSURLRequest *urlRequest = [self requestWithMethod:@"GET" path:path parameters:nil];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest 
       success:^(AFHTTPRequestOperation *operation, id response) {
           NSData *data = (NSData *)response;
           NSString *rawString = [[NSString alloc] initWithData:data encoding:self.stringEncoding];
           NSData *converted = [rawString dataUsingEncoding:NSUTF8StringEncoding];
           TFHpple *pageData = [[TFHpple alloc] initWithHTMLData:converted];
           
           NSMutableDictionary *dict = [NSMutableDictionary dictionary];
           
           TFHppleElement *bookmarkElement = [pageData searchForSingle:@"//input[@name='bookmark' and @checked='checked']"];
           if(bookmarkElement != nil) {
               NSString *bookmark = [bookmarkElement objectForKey:@"value"];
               [dict setValue:bookmark forKey:@"bookmark"];
           }
           
           [dict setValue:@"updatepost" forKey:@"action"];
           [dict setValue:@"Save Changes" forKey:@"submit"];
           [dict setValue:post.postID forKey:@"postid"];
           [dict setValue:contents forKey:@"message"];
           
           NSURLRequest *postRequest = [self requestWithMethod:@"POST" path:@"editpost.php" parameters:dict];
           AFHTTPRequestOperation *finalOp = [self HTTPRequestOperationWithRequest:postRequest 
               success:^(AFHTTPRequestOperation *operation, id response) {
                   if (completionBlock) completionBlock();
               } 
               failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                   if (errorBlock) errorBlock(error);
               }];
           
           [self enqueueHTTPRequestOperation:finalOp];

       } 
       failure:^(AFHTTPRequestOperation *operation, NSError *error) {
           errorBlock(error);
       }];
    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}

-(NSOperation *)submitVote : (int)value forThread : (AwfulThread *)thread onCompletion : (CompletionBlock)completionBlock onError:(AwfulErrorBlock)errorBlock
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    int voteValue = MAX(5, MIN(1, value));
    [dict setValue:[NSNumber numberWithInt:voteValue] forKey:@"vote"];
    [dict setValue:thread.threadID forKey:@"threadid"];
    
    NSURLRequest *urlRequest = [self requestWithMethod:@"POST" path:@"threadrate.php" parameters:dict];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest 
       success:^(AFHTTPRequestOperation *operation, id response) {
           if (completionBlock) completionBlock();
       } 
       failure:^(AFHTTPRequestOperation *operation, NSError *error) {
           if (errorBlock) errorBlock(error);
       }];
    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}

-(NSOperation *)processMarkSeenLink : (NSString *)markSeenLink onCompletion : (CompletionBlock)completionBlock onError:(AwfulErrorBlock)errorBlock
{
    NSString *path = markSeenLink;
    NSURLRequest *urlRequest = [self requestWithMethod:@"GET" path:path parameters:nil];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest 
       success:^(AFHTTPRequestOperation *operation, id response) {
           if (completionBlock) completionBlock();
       } 
       failure:^(AFHTTPRequestOperation *operation, NSError *error) {
           if (errorBlock) errorBlock(error);
       }];
    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}

-(NSOperation *)markThreadUnseen : (AwfulThread *)thread onCompletion : (CompletionBlock)completionBlock onError:(AwfulErrorBlock)errorBlock
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setValue:thread.threadID forKey:@"threadid"];
    [dict setValue:@"resetseen" forKey:@"action"];
    [dict setValue:@"1" forKey:@"json"];
    
    NSString *path = @"showthread.php";
    NSURLRequest *urlRequest = [self requestWithMethod:@"POST" path:path parameters:dict];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest 
       success:^(AFHTTPRequestOperation *operation, id response) {
           if (completionBlock) completionBlock();
       } 
       failure:^(AFHTTPRequestOperation *operation, NSError *error) {
           if (errorBlock) errorBlock(error);
       }];
    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}

- (NSOperation *)logInAsUsername:(NSString *)username
                    withPassword:(NSString *)password
                         andThen:(void (^)(NSError *error))callback
{
    NSDictionary *parameters = @{
        @"action" : @"login",
        @"username" : username,
        @"password" : password
    };
    NSURLRequest *request = [self requestWithMethod:@"POST"
                                               path:@"account.php"
                                         parameters:parameters];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:request
                                                               success:^(id _, id responseObject)
    {
        NSString *response = [[NSString alloc] initWithData:responseObject
                                                   encoding:self.stringEncoding];
        if ([response rangeOfString:@"GLLLUUUUUEEEEEE"].location != NSNotFound) {
            if (callback) callback(nil);
        } else {
            if (callback) callback([NSError errorWithDomain:NSCocoaErrorDomain
                                                       code:-1
                                                   userInfo:nil]);
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error)
    {
        if (callback) callback(error);
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

- (NSOperation *)locatePostWithID:(NSString *)postID
                          andThen:(void (^)(NSError *error, NSString *threadID, NSInteger page))callback
{
    // The SA Forums will direct a certain URL to the thread with a given post. We'll wait for that
    // redirect, then parse out the info we need.
    NSURLRequest *request = [self requestWithMethod:@"GET"
                                               path:@"showthread.php"
                                         parameters:@{ @"goto" : @"post", @"postid" : postID }];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:request
                                                               success:^(id _, id __)
    {
        // Once we have the redirect we want, we cancel the operation. So if this "success" callback
        // gets called, we've actually failed.
        if (callback) callback(nil, nil, 0);
    } failure:^(id _, NSError *error)
    {
        if (callback) callback(error, nil, 0);
    }];
    __weak AFHTTPRequestOperation *blockOp = op;
    [op setRedirectResponseBlock:^NSURLRequest *(id _, NSURLRequest *request, NSURLResponse *response)
    {
        if (!response) return request;
        [blockOp cancel];
        NSDictionary *query = [[request URL] queryDictionary];
        if (callback) {
            dispatch_queue_t queue = blockOp.successCallbackQueue;
            if (!queue) queue = dispatch_get_main_queue();
            dispatch_async(queue, ^{
                callback(nil, query[@"threadid"], [query[@"pagenumber"] integerValue]);
            });
        }
        return nil;
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

@end
