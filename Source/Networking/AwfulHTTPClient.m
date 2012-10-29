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
#import "AwfulPageTemplate.h"
#import "AwfulParsing.h"
#import "AwfulSettings.h"
#import "NSManagedObject+Awful.h"

@implementation AwfulHTTPClient

+ (AwfulHTTPClient *)client
{
    static AwfulHTTPClient *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[AwfulHTTPClient alloc] initWithBaseURL:
                    [NSURL URLWithString:@"http://forums.somethingawful.com/"]];
    });
    return instance;
}

- (id)initWithBaseURL:(NSURL *)url
{
    self = [super initWithBaseURL:url];
    if (self) {
        self.stringEncoding = NSWindowsCP1252StringEncoding;
    }
    return self;
}

static NSData *ConvertFromWindows1252ToUTF8(NSData *windows1252)
{
    NSString *ugh = [[NSString alloc] initWithData:windows1252
                                          encoding:NSWindowsCP1252StringEncoding];
    return [ugh dataUsingEncoding:NSUTF8StringEncoding];
}

- (NSOperation *)listThreadsInForumWithID:(NSString *)forumID
                                   onPage:(NSInteger)page
                                  andThen:(void (^)(NSError *error, NSArray *threads))callback
{
    NSDictionary *parameters = @{ @"forumid": forumID, @"perpage": @40, @"pagenumber": @(page) };
    NSURLRequest *request = [self requestWithMethod:@"GET"
                                               path:@"forumdisplay.php"
                                         parameters:parameters];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:request
                                                               success:^(id _, id data)
    {
        NSArray *infos = [ThreadParsedInfo threadsWithHTMLData:ConvertFromWindows1252ToUTF8(data)];
        NSArray *threads = [AwfulThread threadsCreatedOrUpdatedWithParsedInfo:infos];
        NSInteger stickyIndex = -(NSInteger)[threads count];
        NSArray *forums = [AwfulForum fetchAllMatchingPredicate:@"forumID = %@", forumID];
        for (AwfulThread *thread in threads) {
            if ([forums count] > 0) thread.forum = forums[0];
            thread.stickyIndexValue = thread.isStickyValue ? stickyIndex++ : 0;
        }
        [[AwfulDataStack sharedDataStack] save];
        if (callback) callback(nil, threads);
    } failure:^(id _, NSError *error) {
        if (callback) callback(error, nil);
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

- (NSOperation *)listBookmarkedThreadsOnPage:(NSInteger)page
                                     andThen:(void (^)(NSError *error, NSArray *threads))callback
{
    NSDictionary *parameters = @{ @"action": @"view", @"perpage": @40, @"pagenumber": @(page) };
    NSURLRequest *request = [self requestWithMethod:@"GET"
                                               path:@"bookmarkthreads.php"
                                         parameters:parameters];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:request
                                                               success:^(id _, id data)
    {
        NSArray *threadInfos = [ThreadParsedInfo threadsWithHTMLData:
                                ConvertFromWindows1252ToUTF8(data)];
        NSArray *threads = [AwfulThread threadsCreatedOrUpdatedWithParsedInfo:threadInfos];
        [threads setValue:@YES forKey:AwfulThreadAttributes.isBookmarked];
        [[AwfulDataStack sharedDataStack] save];
        if (callback) callback(nil, threads);
    } failure:^(id _, NSError *error) {
        if (callback) callback(error, nil);
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

- (NSOperation *)listPostsInThreadWithID:(NSString *)threadID
    onPage:(NSInteger)page
    andThen:(void (^)(NSError *error, NSArray *posts, NSString *advertisementHTML))callback
{
    NSMutableDictionary *parameters = [@{ @"threadid": threadID } mutableCopy];
    if (page == AwfulPageNextUnread) parameters[@"goto"] = @"newpost";
    else if (page == AwfulPageLast) parameters[@"goto"] = @"lastpost";
    else parameters[@"pagenumber"] = @(page);
    NSURLRequest *request = [self requestWithMethod:@"GET"
                                               path:@"showthread.php"
                                         parameters:parameters];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:request
                                                               success:^(id _, id data)
    {
        PageParsedInfo *info = [[PageParsedInfo alloc] initWithHTMLData:
                                ConvertFromWindows1252ToUTF8(data)];
        NSArray *posts = [AwfulPost postsCreatedOrUpdatedFromPageInfo:info];
        if (callback) callback(nil, posts, info.advertisementHTML);
    } failure:^(id _, NSError *error) {
        if (callback) callback(error, nil, nil);
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

- (NSOperation *)learnUserInfoAndThen:(void (^)(NSError *error, NSDictionary *userInfo))callback
{
    NSDictionary *parameters = @{ @"action": @"editprofile" };
    NSURLRequest *urlRequest = [self requestWithMethod:@"GET"
                                                  path:@"member.php"
                                            parameters:parameters];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest 
                                                               success:^(id _, id data)
    {
        UserParsedInfo *parsed = [[UserParsedInfo alloc] initWithHTMLData:
                                  ConvertFromWindows1252ToUTF8(data)];
        if (callback) callback(nil, @{ @"userID": parsed.userID, @"username": parsed.username });
    } failure:^(id _, NSError *error) {
        if (callback) callback(error, nil);
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

- (NSOperation *)setThreadWithID:(NSString *)threadID
                    isBookmarked:(BOOL)isBookmarked
                         andThen:(void (^)(NSError *error))callback
{
    NSDictionary *parameters = @{
        @"json": @"1",
        @"action": isBookmarked ? @"add" : @"remove",
        @"threadid": threadID
    };
    NSURLRequest *request = [self requestWithMethod:@"POST"
                                               path:@"bookmarkthreads.php"
                                         parameters:parameters];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:request
                                                               success:^(id _, id __)
    {
        if (callback) callback(nil);
    } failure:^(id _, NSError *error) {
        if (callback) callback(error);
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

- (NSOperation *)listForumsAndThen:(void (^)(NSError *error, NSArray *forums))callback
{
    // Seems like only forumdisplay.php and showthread.php have the <select> with a complete list
    // of forums. We'll use the Comedy Goldmine as it's generally available and hopefully it's not
    // much of a burden since threads rarely get goldmined.
    NSURLRequest *urlRequest = [self requestWithMethod:@"GET"
                                                  path:@"forumdisplay.php"
                                            parameters:@{ @"forumid": @"21" }];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest
                                                               success:^(id _, id data)
    {
        ForumHierarchyParsedInfo *info = [[ForumHierarchyParsedInfo alloc] initWithHTMLData:
                                          ConvertFromWindows1252ToUTF8(data)];
        NSArray *forums = [AwfulForum updateCategoriesAndForums:info];
        if (callback) callback(nil, forums);
    } failure:^(id _, NSError *error) {
        if (callback) callback(error, nil);
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
        ReplyFormParsedInfo *formInfo = [[ReplyFormParsedInfo alloc] initWithHTMLData:
                                         ConvertFromWindows1252ToUTF8(data)];
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
                                                                        success:^(id _, id data)
        {
            SuccessfulReplyInfo *replyInfo = [[SuccessfulReplyInfo alloc] initWithHTMLData:
                                              ConvertFromWindows1252ToUTF8(data)];
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

- (NSOperation *)getTextOfPostWithID:(NSString *)postID
                             andThen:(void (^)(NSError *error, NSString *text))callback
{
    NSURLRequest *request = [self requestWithMethod:@"GET"
                                               path:@"editpost.php"
                                         parameters:@{ @"action": @"editpost", @"postid": postID }];
    return [self textOfPostWithRequest:request andThen:callback];
}

- (NSOperation *)quoteTextOfPostWithID:(NSString *)postID
                               andThen:(void (^)(NSError *error, NSString *quotedText))callback
{
    NSURLRequest *request = [self requestWithMethod:@"GET"
                                               path:@"newreply.php"
                                         parameters:@{ @"action": @"newreply", @"postid": postID }];
    return [self textOfPostWithRequest:request andThen:callback];
}

- (NSOperation *)textOfPostWithRequest:(NSURLRequest *)request
                               andThen:(void (^)(NSError *, NSString *))callback
{
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:request
                                                               success:^(id _, id data)
    {
        ReplyFormParsedInfo *formInfo = [[ReplyFormParsedInfo alloc] initWithHTMLData:
                                         ConvertFromWindows1252ToUTF8(data)];
        if (callback) callback(nil, formInfo.text);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil);
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

- (NSOperation *)editPostWithID:(NSString *)postID
                           text:(NSString *)text
                        andThen:(void (^)(NSError *error))callback
{
    NSDictionary *parameters = @{ @"action": @"editpost", @"postid": postID };
    NSURLRequest *request = [self requestWithMethod:@"GET"
                                               path:@"editpost.php"
                                         parameters:parameters];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:request
                                                               success:^(id _, id data)
    {
        NSMutableDictionary *moreParameters = [@{
             @"action": @"updatepost",
             @"submit": @"Save Changes",
             @"postid": postID,
             @"message": text
         } mutableCopy];
        ReplyFormParsedInfo *formInfo = [[ReplyFormParsedInfo alloc] initWithHTMLData:
                                         ConvertFromWindows1252ToUTF8(data)];
        if (formInfo.bookmark) {
            moreParameters[@"bookmark"] = formInfo.bookmark;
        }
        NSURLRequest *anotherRequest = [self requestWithMethod:@"POST"
                                                          path:@"editpost.php"
                                                    parameters:moreParameters];
        AFHTTPRequestOperation *finalOp = [self HTTPRequestOperationWithRequest:anotherRequest
                                                                        success:^(id _, id __)
        {
            if (callback) callback(nil);
        } failure:^(id _, NSError *error) {
            if (callback) callback(error);
        }];
        
        [self enqueueHTTPRequestOperation:finalOp];
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error);
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

- (NSOperation *)rateThreadWithID:(NSString *)threadID
                           rating:(NSInteger)rating
                          andThen:(void (^)(NSError *error))callback
{
    NSDictionary *parameters = @{ @"vote": @(MAX(5, MIN(1, rating))), @"threadid": threadID };
    NSURLRequest *request = [self requestWithMethod:@"POST"
                                               path:@"threadrate.php"
                                         parameters:parameters];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:request
                                                               success:^(id _, id __)
    {
        if (callback) callback(nil);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error);
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

- (NSOperation *)markThreadWithID:(NSString *)threadID
              readUpToPostAtIndex:(NSString *)index
                          andThen:(void (^)(NSError *error))callback
{
    NSDictionary *parameters = @{ @"action": @"setseen", @"threadid": threadID, @"index": index };
    NSURLRequest *request = [self requestWithMethod:@"GET"
                                               path:@"showthread.php"
                                         parameters:parameters];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:request
                                                               success:^(id _, id __)
    {
        if (callback) callback(nil);
    } failure:^(id _, NSError *error) {
        if (callback) callback(error);
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

- (NSOperation *)forgetReadPostsInThreadWithID:(NSString *)threadID
                                       andThen:(void (^)(NSError *error))callback
{
    NSDictionary *parameters = @{ @"threadid": threadID, @"action": @"resetseen", @"json": @"1" };
    NSURLRequest *request = [self requestWithMethod:@"POST"
                                               path:@"showthread.php"
                                         parameters:parameters];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:request
                                                               success:^(id _, id __)
    {
           if (callback) callback(nil);
    } failure:^(id _, NSError *error) {
           if (callback) callback(error);
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
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
                                                               success:^(id _, id data)
    {
        NSString *response = [[NSString alloc] initWithData:data encoding:self.stringEncoding];
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
