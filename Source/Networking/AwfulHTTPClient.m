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
#import "AwfulParsing.h"
#import "AwfulSettings.h"
#import "NSManagedObject+Awful.h"

@interface AwfulHTTPClient ()

@property (getter=isReachable, nonatomic) BOOL reachable;

@property (nonatomic) dispatch_queue_t parseQueue;

@end


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
        _parseQueue = dispatch_queue_create("com.awfulapp.Awful.parsing", NULL);
        [self setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
            self.reachable = status != AFNetworkReachabilityStatusNotReachable;
        }];
    }
    return self;
}

- (void)dealloc
{
    dispatch_release(_parseQueue);
}

static NSData *ConvertFromWindows1252ToUTF8(NSData *windows1252)
{
    NSString *ugh = [[NSString alloc] initWithData:windows1252
                                          encoding:NSWindowsCP1252StringEncoding];
    // Sometimes it isn't windows-1252 and is actually what's sent in headers: ISO-8859-1.
    // Example: http://forums.somethingawful.com/showthread.php?threadid=2357406&pagenumber=2
    // Maybe it's just old posts; the example is from 2007. And we definitely get some mojibake,
    // but at least it's something.
    if (!ugh) {
        ugh = [[NSString alloc] initWithData:windows1252 encoding:NSISOLatin1StringEncoding];
    }
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
        dispatch_async(self.parseQueue, ^{
            NSArray *infos = [ThreadParsedInfo threadsWithHTMLData:
                              ConvertFromWindows1252ToUTF8(data)];
            dispatch_async(dispatch_get_main_queue(), ^{
                NSArray *threads = [AwfulThread threadsCreatedOrUpdatedWithParsedInfo:infos];
                NSInteger stickyIndex = -(NSInteger)[threads count];
                NSArray *forums = [AwfulForum fetchAllMatchingPredicate:@"forumID = %@", forumID];
                for (AwfulThread *thread in threads) {
                    if ([forums count] > 0) thread.forum = forums[0];
                    thread.stickyIndexValue = thread.isStickyValue ? stickyIndex++ : 0;
                }
                [[AwfulDataStack sharedDataStack] save];
                if (callback) callback(nil, threads);
            });
        });
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
        dispatch_async(self.parseQueue, ^{
            NSArray *threadInfos = [ThreadParsedInfo threadsWithHTMLData:
                                    ConvertFromWindows1252ToUTF8(data)];
            dispatch_async(dispatch_get_main_queue(), ^{
                NSArray *threads = [AwfulThread threadsCreatedOrUpdatedWithParsedInfo:threadInfos];
                [threads setValue:@YES forKey:AwfulThreadAttributes.isBookmarked];
                [[AwfulDataStack sharedDataStack] save];
                if (callback) callback(nil, threads);
            });
        });
    } failure:^(id _, NSError *error) {
        if (callback) callback(error, nil);
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

- (NSOperation *)listPostsInThreadWithID:(NSString *)threadID
                                  onPage:(NSInteger)page
                                 andThen:(void (^)(NSError *error,
                                                   NSArray *posts,
                                                   NSUInteger firstUnreadPost,
                                                   NSString *advertisementHTML))callback
{
    NSMutableDictionary *parameters = [@{ @"threadid": threadID } mutableCopy];
    parameters[@"perpage"] = @40;
    if (page == AwfulPageNextUnread) parameters[@"goto"] = @"newpost";
    else if (page == AwfulPageLast) parameters[@"goto"] = @"lastpost";
    else parameters[@"pagenumber"] = @(page);
    NSURLRequest *request = [self requestWithMethod:@"GET"
                                               path:@"showthread.php"
                                         parameters:parameters];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:request
                                                               success:^(id op, id data)
    {
        dispatch_async(self.parseQueue, ^{
            PageParsedInfo *info = [[PageParsedInfo alloc] initWithHTMLData:
                                    ConvertFromWindows1252ToUTF8(data)];
            dispatch_async(dispatch_get_main_queue(), ^{
                NSArray *posts = [AwfulPost postsCreatedOrUpdatedFromPageInfo:info];
                if (callback) {
                    NSInteger firstUnreadPost = NSNotFound;
                    if (page == AwfulPageNextUnread) {
                        NSString *fragment = [[[op response] URL] fragment];
                        if ([fragment hasPrefix:@"pti"]) {
                            firstUnreadPost = [[fragment substringFromIndex:3] integerValue] - 1;
                            if (firstUnreadPost < 0) firstUnreadPost = NSNotFound;
                        }
                    }
                    callback(nil, posts, firstUnreadPost, info.advertisementHTML);
                }
            });
        });
    } failure:^(id _, NSError *error) {
        if (callback) callback(error, nil, NSNotFound, nil);
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
        dispatch_async(self.parseQueue, ^{
            ProfileParsedInfo *parsed = [[ProfileParsedInfo alloc] initWithHTMLData:
                                      ConvertFromWindows1252ToUTF8(data)];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (callback) callback(nil, @{ @"userID": parsed.userID, @"username": parsed.username });
            });
        });
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
        dispatch_async(self.parseQueue, ^{
            ForumHierarchyParsedInfo *info = [[ForumHierarchyParsedInfo alloc] initWithHTMLData:
                                              ConvertFromWindows1252ToUTF8(data)];
            dispatch_async(dispatch_get_main_queue(), ^{
                NSArray *forums = [AwfulForum updateCategoriesAndForums:info];
                if (callback) callback(nil, forums);
            });
        });
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
        dispatch_async(self.parseQueue, ^{
            ReplyFormParsedInfo *formInfo = [[ReplyFormParsedInfo alloc] initWithHTMLData:
                                             ConvertFromWindows1252ToUTF8(data)];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!(formInfo.formkey && formInfo.formCookie)) {
                    NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : @"Thread is closed" };
                    NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                                         code:-1
                                                     userInfo:userInfo];
                    if (callback) callback(error, nil);
                    return;
                }
                NSMutableDictionary *postParameters = [@{
                                                       @"threadid" : threadID,
                                                       @"formkey" : formInfo.formkey,
                                                       @"form_cookie" : formInfo.formCookie,
                                                       @"action" : @"postreply",
                                                       @"message" : Entitify(text),
                                                       @"parseurl" : @"yes",
                                                       @"submit" : @"Submit Reply",
                                                       } mutableCopy];
                if (formInfo.bookmark) {
                    postParameters[@"bookmark"] = formInfo.bookmark;
                }
                
                NSURLRequest *postRequest = [self requestWithMethod:@"POST"
                                                               path:@"newreply.php"
                                                         parameters:postParameters];
                AFHTTPRequestOperation *opTwo;
                opTwo = [self HTTPRequestOperationWithRequest:postRequest
                                                      success:^(id _, id data)
                         {
                             dispatch_async(self.parseQueue, ^{
                                 SuccessfulReplyInfo *replyInfo;
                                 replyInfo = [[SuccessfulReplyInfo alloc] initWithHTMLData:
                                              ConvertFromWindows1252ToUTF8(data)];
                                 dispatch_async(dispatch_get_main_queue(), ^{
                                     NSString *postID = replyInfo.lastPage ? nil : replyInfo.postID;
                                     if (callback) callback(nil, postID);
                                 });
                             });
                         } failure:^(id _, NSError *error)
                         {
                             if (callback) callback(error, nil);
                         }];
                [self enqueueHTTPRequestOperation:opTwo];
            });
        });
    } failure:^(id _, NSError *error)
    {
        if (callback) callback(error, nil);
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

static NSString * Entitify(NSString *noEntities)
{
    // Replace all characters outside windows-1252 with XML entities.
    noEntities = [noEntities precomposedStringWithCanonicalMapping];
    NSMutableString *withEntities = [noEntities mutableCopy];
    NSError *error;
    NSString *pattern = @"(?x)[^ \\u0000-\\u007F \\u20AC \\u201A \\u0192 \u201E \\u2026 \\u2020 "
                         "\\u2021 \\u02C6 \\u2030 \\u0160 \\u2039 \\u0152 \\u017D \\u2018 \\u2019 "
                         "\\u201C \\u201D \\u2022 \\u2013 \\u2014 \\u02DC \\u2122 \\u0161 \\u203A "
                         "\\u0153 \\u017E \\u0178 \\u00A0-\\u00FF ]";
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                           options:0
                                                                             error:&error];
    if (!regex) {
        NSLog(@"error creating regex in Entitify: %@", error);
        return nil;
    }
    __block NSInteger offset = 0;
    NSNumberFormatter *formatter = [NSNumberFormatter new];
    [formatter setNumberStyle:NSNumberFormatterNoStyle];
    [regex enumerateMatchesInString:noEntities
                            options:0
                              range:NSMakeRange(0, [noEntities length])
                         usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags _, BOOL *__)
    {
        NSMutableString *replacement = [NSMutableString new];
        NSString *needsEntity = [noEntities substringWithRange:[result range]];
        uint32_t codepoint;
        NSRange remaining = NSMakeRange(0, [needsEntity length]);
        while ([needsEntity getBytes:&codepoint
                           maxLength:sizeof(codepoint)
                          usedLength:NULL
                            encoding:NSUTF32LittleEndianStringEncoding
                             options:0
                               range:remaining
                      remainingRange:&remaining]) {
            NSNumber *number = [NSNumber numberWithUnsignedInt:CFSwapInt32LittleToHost(codepoint)];
            [replacement appendFormat:@"&#%@;", [formatter stringFromNumber:number]];
        }
        NSRange replacementRange = [result range];
        replacementRange.location += offset;
        [withEntities replaceCharactersInRange:replacementRange withString:replacement];
        offset += [replacement length] - replacementRange.length;
    }];
    return withEntities;
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
        dispatch_async(self.parseQueue, ^{
            ReplyFormParsedInfo *formInfo = [[ReplyFormParsedInfo alloc] initWithHTMLData:
                                             ConvertFromWindows1252ToUTF8(data)];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (callback) callback(nil, formInfo.text);
            });
        });
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
             @"message": Entitify(text)
         } mutableCopy];
        dispatch_async(self.parseQueue, ^{
            ReplyFormParsedInfo *formInfo = [[ReplyFormParsedInfo alloc] initWithHTMLData:
                                             ConvertFromWindows1252ToUTF8(data)];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (formInfo.bookmark) {
                    moreParameters[@"bookmark"] = formInfo.bookmark;
                }
                NSURLRequest *anotherRequest = [self requestWithMethod:@"POST"
                                                                  path:@"editpost.php"
                                                            parameters:moreParameters];
                AFHTTPRequestOperation *finalOp;
                finalOp = [self HTTPRequestOperationWithRequest:anotherRequest
                                                        success:^(id _, id __)
                           {
                               if (callback) callback(nil);
                           } failure:^(id _, NSError *error) {
                               if (callback) callback(error);
                           }];
                [self enqueueHTTPRequestOperation:finalOp];
            });
        });
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

- (NSOperation *)profileUserWithID:(NSString *)userID
                           andThen:(void (^)(NSError *error, AwfulUser *user))callback
{
    NSDictionary *parameters = @{ @"action": @"getinfo", @"userid": userID };
    NSURLRequest *request = [self requestWithMethod:@"GET"
                                               path:@"member.php"
                                         parameters:parameters];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:request
                                                               success:^(id op, id data)
    {
        dispatch_async(self.parseQueue, ^{
            ProfileParsedInfo *info = [[ProfileParsedInfo alloc] initWithHTMLData:
                                       ConvertFromWindows1252ToUTF8(data)];
            info.userID = userID;
            dispatch_async(dispatch_get_main_queue(), ^{
                AwfulUser *user = [AwfulUser userCreatedOrUpdatedFromProfileInfo:info];
                if (user.profilePictureURL && [user.profilePictureURL hasPrefix:@"/"]) {
                    NSString *base = [self.baseURL absoluteString];
                    base = [base substringToIndex:[base length] - 1];
                    user.profilePictureURL = [base stringByAppendingString:user.profilePictureURL];
                    [[AwfulDataStack sharedDataStack] save];
                }
                if (callback) callback(nil, user);
            });
        });
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil);
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

@end
