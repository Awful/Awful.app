//
//  AwfulHTTPClient.m
//  Awful
//
//  Created by Sean Berry on 5/26/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulHTTPClient.h"
#import "AwfulDataStack.h"
#import "AwfulJSONOrScrapeOperation.h"
#import "AwfulModels.h"
#import "AwfulParsing.h"
#import "AwfulSettings.h"
#import "NSManagedObject+Awful.h"
#import "NSURL+QueryDictionary.h"

@interface AwfulHTTPClient ()

@property (getter=isReachable, nonatomic) BOOL reachable;

@property (readonly, nonatomic) BOOL usingDevDotForums;

@end


@implementation AwfulHTTPClient

static AwfulHTTPClient *instance = nil;

+ (AwfulHTTPClient *)client
{
    @synchronized([AwfulHTTPClient class]) {
        if (!instance) {
            NSURL *baseURL = [NSURL URLWithString:@"http://forums.somethingawful.com/"];
            if ([AwfulSettings settings].useDevDotForums) {
                baseURL = [NSURL URLWithString:@"http://dev.forums.somethingawful.com/"];
            }
            instance = [[AwfulHTTPClient alloc] initWithBaseURL:baseURL];
        }
    }
    return instance;
}

+ (void)initialize
{
    if (self != [AwfulHTTPClient class]) return;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsDidChange:)
                                                 name:AwfulSettingsDidChangeNotification
                                               object:nil];
}

+ (void)settingsDidChange:(NSNotification *)note
{
    NSArray *keys = note.userInfo[AwfulSettingsDidChangeSettingsKey];
    if (![keys containsObject:AwfulSettingsKeys.useDevDotForums]) return;
    // Clear the singleton instance so it's recreated on next access.
    // Not synchronizing; I don't really care if some last thread gets the old client.
    instance = nil;
}

- (BOOL)isLoggedIn
{
    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:self.baseURL];
    return [[cookies valueForKey:@"name"] containsObject:@"bbuserid"];
}

- (BOOL)usingDevDotForums
{
    return [self.baseURL.host hasPrefix:@"dev.forums"];
}

- (id)initWithBaseURL:(NSURL *)url
{
    self = [super initWithBaseURL:url];
    if (self) {
        self.stringEncoding = NSWindowsCP1252StringEncoding;
        __weak AwfulHTTPClient *weakSelf = self;
        [self setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
            weakSelf.reachable = status != AFNetworkReachabilityStatusNotReachable;
        }];
        [self registerHTTPOperationClass:[AwfulJSONOrScrapeOperation class]];
    }
    return self;
}

- (NSOperation *)listThreadsInForumWithID:(NSString *)forumID
                                   onPage:(NSInteger)page
                                  andThen:(void (^)(NSError *error, NSArray *threads))callback
{
    NSMutableDictionary *parameters = [@{
        @"forumid": forumID,
        @"perpage": @40,
        @"pagenumber": @(page),
    } mutableCopy];
    if (self.usingDevDotForums) {
        parameters[@"json"] = @1;
    }
    NSURLRequest *request = [self requestWithMethod:@"GET" path:@"forumdisplay.php"
                                         parameters:parameters];
    id op = [self HTTPRequestOperationWithRequest:request
                                          success:^(id _, id responseObject)
    {
        NSArray *threads;
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            threads = [AwfulThread threadsCreatedOrUpdatedWithJSON:responseObject];
        } else {
            threads = [AwfulThread threadsCreatedOrUpdatedWithParsedInfo:responseObject];
        }
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
    [op setCreateParsedInfoBlock:^id(NSData *data) {
        return [ThreadParsedInfo threadsWithHTMLData:data];
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

- (NSOperation *)listBookmarkedThreadsOnPage:(NSInteger)page
                                     andThen:(void (^)(NSError *error, NSArray *threads))callback
{
    NSMutableDictionary *parameters = [@{
        @"action": @"view",
        @"perpage": @40,
        @"pagenumber": @(page),
    } mutableCopy];
    if (self.usingDevDotForums) {
        parameters[@"json"] = @1;
    }
    NSURLRequest *request = [self requestWithMethod:@"GET" path:@"bookmarkthreads.php"
                                         parameters:parameters];
    id op = [self HTTPRequestOperationWithRequest:request
                                          success:^(id _, id responseObject)
    {
        NSArray *threads;
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            threads = [AwfulThread threadsCreatedOrUpdatedWithJSON:responseObject];
        } else {
            threads = [AwfulThread threadsCreatedOrUpdatedWithParsedInfo:responseObject];
        }
        if (callback) callback(nil, threads);
    } failure:^(id _, NSError *error) {
        if (callback) callback(error, nil);
    }];
    [op setCreateParsedInfoBlock:^id(NSData *data) {
        return [ThreadParsedInfo threadsWithHTMLData:data];
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

- (NSOperation *)listPostsInThreadWithID:(NSString *)threadID
                                  onPage:(AwfulThreadPage)page
                                 andThen:(void (^)(NSError *error,
                                                   NSArray *posts,
                                                   NSUInteger firstUnreadPost,
                                                   NSString *advertisementHTML))callback
{
    NSMutableDictionary *parameters = [@{ @"threadid": threadID } mutableCopy];
    if (self.usingDevDotForums) {
        parameters[@"json"] = @1;
    }
    parameters[@"perpage"] = @40;
    if (page == AwfulThreadPageNextUnread) parameters[@"goto"] = @"newpost";
    else if (page == AwfulThreadPageLast) parameters[@"goto"] = @"lastpost";
    else parameters[@"pagenumber"] = @(page);
    NSURLRequest *request = [self requestWithMethod:@"GET" path:@"showthread.php"
                                         parameters:parameters];
    id op = [self HTTPRequestOperationWithRequest:request
                                          success:^(id op, id responseObject)
    {
        NSArray *posts;
        NSString *ad;
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            posts = [AwfulPost postsCreatedOrUpdatedFromJSON:responseObject];
            ad = [responseObject valueForKey:@"goon_banner"];
            if ([ad isEqual:[NSNull null]]) ad = nil;
        } else {
            posts = [AwfulPost postsCreatedOrUpdatedFromPageInfo:responseObject];
            ad = [responseObject advertisementHTML];
        }
        if (callback) {
            NSInteger firstUnreadPost = NSNotFound;
            if (page == AwfulThreadPageNextUnread) {
                NSString *fragment = [[[op response] URL] fragment];
                if ([fragment hasPrefix:@"pti"]) {
                    firstUnreadPost = [[fragment substringFromIndex:3] integerValue] - 1;
                    if (firstUnreadPost < 0) firstUnreadPost = NSNotFound;
                }
            }
            callback(nil, posts, firstUnreadPost, ad);
        }
    } failure:^(id _, NSError *error) {
        if (callback) callback(error, nil, NSNotFound, nil);
    }];
    [op setCreateParsedInfoBlock:^id(NSData *data) {
        return [[PageParsedInfo alloc] initWithHTMLData:data];
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

- (NSOperation *)learnUserInfoAndThen:(void (^)(NSError *error, NSDictionary *userInfo))callback
{
    NSDictionary *parameters = @{ @"action": @"getinfo", @"json": @1 };
    NSURLRequest *urlRequest = [self requestWithMethod:@"GET" path:@"member.php"
                                            parameters:parameters];
    id op = [self HTTPRequestOperationWithRequest:urlRequest
                                          success:^(id _, id responseObject)
    {
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            AwfulUser *user = [AwfulUser userCreatedOrUpdatedFromJSON:responseObject];
            if (callback) callback(nil, [user dictionaryWithValuesForKeys:@[ @"userID", @"username" ]]);
        } else {
            ProfileParsedInfo *profile = responseObject;
            if (callback) callback(nil, @{ @"userID": profile.userID, @"username": profile.username });
        }
    } failure:^(id _, NSError *error) {
        if (callback) callback(error, nil);
    }];
    [op setCreateParsedInfoBlock:^id(NSData *data) {
        return [[ProfileParsedInfo alloc] initWithHTMLData:data];
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
    NSURLRequest *request = [self requestWithMethod:@"POST" path:@"bookmarkthreads.php"
                                         parameters:parameters];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:request
                                                               success:^(id _, id __)
    {
        AwfulThread *thread = [AwfulThread firstMatchingPredicate:@"threadID = %@", threadID];
        thread.isBookmarkedValue = isBookmarked;
        [[AwfulDataStack sharedDataStack] save];
        if (callback) callback(nil);
    } failure:^(id _, NSError *error) {
        if (callback) callback(error);
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

- (NSOperation *)listForumsAndThen:(void (^)(NSError *error, NSArray *forums))callback
{
    if (self.usingDevDotForums) {
        NSURLRequest *urlRequest = [self requestWithMethod:@"GET" path:@""
                                                parameters:@{ @"json": @1 }];
        AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest
                                                                   success:^(id _, NSDictionary *json)
        {
            if (![json[@"forums"] isKindOfClass:[NSArray class]]) {
                NSDictionary *userInfo = @{
                    NSLocalizedDescriptionKey: @"The forums list could not be parsed"
                };
                NSError *error = [NSError errorWithDomain:AwfulErrorDomain
                                                     code:AwfulErrorCodes.parseError
                                                 userInfo:userInfo];
                if (callback) callback(error, nil);
                return;
            }
            NSArray *forums = [AwfulForum updateCategoriesAndForumsWithJSON:json[@"forums"]];
            if (callback) callback(nil, forums);
        } failure:^(id _, NSError *error) {
            if (callback) callback(error, nil);
        }];
        [self enqueueHTTPRequestOperation:op];
        return op;
    } else {
        // Seems like only forumdisplay.php and showthread.php have the <select> with a complete
        // list of forums. We'll use the Main "forum" as it's the smallest page with the drop-down
        // list.
        NSURLRequest *urlRequest = [self requestWithMethod:@"GET"
                                                      path:@"forumdisplay.php"
                                                parameters:@{ @"forumid": @"48" }];
        id op = [self HTTPRequestOperationWithRequest:urlRequest
                                              success:^(id _, ForumHierarchyParsedInfo *info)
        {
            NSArray *forums = [AwfulForum updateCategoriesAndForums:info];
            if (callback) callback(nil, forums);
        } failure:^(id _, NSError *error) {
            if (callback) callback(error, nil);
        }];
        [op setCreateParsedInfoBlock:^id(NSData *data) {
            return [[ForumHierarchyParsedInfo alloc] initWithHTMLData:data];
        }];
        [self enqueueHTTPRequestOperation:op];
        return op;
    }    
}

- (NSOperation *)replyToThreadWithID:(NSString *)threadID
                                text:(NSString *)text
                             andThen:(void (^)(NSError *error, NSString *postID))callback
{
    NSDictionary *parameters = @{ @"action" : @"newreply", @"threadid" : threadID };
    NSURLRequest *urlRequest = [self requestWithMethod:@"GET" path:@"newreply.php"
                                            parameters:parameters];
    id op = [self HTTPRequestOperationWithRequest:urlRequest
                                          success:^(id _, ReplyFormParsedInfo *formInfo)
    {
        if (!(formInfo.formkey && formInfo.formCookie)) {
            NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : @"Thread is closed" };
            NSError *error = [NSError errorWithDomain:AwfulErrorDomain
                                                 code:AwfulErrorCodes.threadIsClosed
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
        
        NSURLRequest *postRequest = [self requestWithMethod:@"POST" path:@"newreply.php"
                                                 parameters:postParameters];
        id opTwo = [self HTTPRequestOperationWithRequest:postRequest
                                                 success:^(id _, SuccessfulReplyInfo *replyInfo)
                 {
                     NSString *postID = replyInfo.lastPage ? nil : replyInfo.postID;
                     if (callback) callback(nil, postID);
                 } failure:^(id _, NSError *error)
                 {
                     if (callback) callback(error, nil);
                 }];
        [opTwo setCreateParsedInfoBlock:^id(NSData *data) {
            return [[SuccessfulReplyInfo alloc] initWithHTMLData:data];
        }];
        [self enqueueHTTPRequestOperation:opTwo];
    } failure:^(id _, NSError *error)
    {
        if (callback) callback(error, nil);
    }];
    [op setCreateParsedInfoBlock:^id(NSData *data) {
        return [[ReplyFormParsedInfo alloc] initWithHTMLData:data];
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
    NSURLRequest *request = [self requestWithMethod:@"GET" path:@"editpost.php"
                                         parameters:@{ @"action": @"editpost", @"postid": postID }];
    id op = [self HTTPRequestOperationWithRequest:request
                                          success:^(id _, ReplyFormParsedInfo *formInfo)
    {
        if (callback) callback(nil, formInfo.text);
    } failure:^(id _, NSError *error) {
        if (callback) callback(error, nil);
    }];
    [op setCreateParsedInfoBlock:^id(NSData *data) {
        return [[ReplyFormParsedInfo alloc] initWithHTMLData:data];
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

- (NSOperation *)quoteTextOfPostWithID:(NSString *)postID
                               andThen:(void (^)(NSError *error, NSString *quotedText))callback
{
    NSDictionary *parameters = @{ @"action": @"newreply", @"postid": postID, @"json": @1 };
    NSURLRequest *request = [self requestWithMethod:@"GET" path:@"newreply.php"
                                         parameters:parameters];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:request
                                                               success:^(id _, NSDictionary *json)
    {
        if (callback) callback(nil, json[@"body"]);
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
    NSURLRequest *request = [self requestWithMethod:@"GET" path:@"editpost.php"
                                         parameters:parameters];
    id op = [self HTTPRequestOperationWithRequest:request
                                          success:^(id _, ReplyFormParsedInfo *formInfo)
    {
        NSMutableDictionary *moreParameters = [@{
             @"action": @"updatepost",
             @"submit": @"Save Changes",
             @"postid": postID,
             @"message": Entitify(text)
         } mutableCopy];
        if (formInfo.bookmark) {
            moreParameters[@"bookmark"] = formInfo.bookmark;
        }
        NSURLRequest *anotherRequest = [self requestWithMethod:@"POST" path:@"editpost.php"
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
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error);
    }];
    [op setCreateParsedInfoBlock:^id(NSData *data) {
        return [[ReplyFormParsedInfo alloc] initWithHTMLData:data];
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

- (NSOperation *)rateThreadWithID:(NSString *)threadID
                           rating:(NSInteger)rating
                          andThen:(void (^)(NSError *error))callback
{
    NSDictionary *parameters = @{ @"vote": @(MAX(5, MIN(1, rating))), @"threadid": threadID };
    NSURLRequest *request = [self requestWithMethod:@"POST" path:@"threadrate.php"
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
    NSURLRequest *request = [self requestWithMethod:@"GET" path:@"showthread.php"
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
    NSURLRequest *request = [self requestWithMethod:@"POST" path:@"showthread.php"
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
                         andThen:(void (^)(NSError *error, NSDictionary *userInfo))callback
{
    NSDictionary *parameters = @{
        @"action" : @"login",
        @"username" : username,
        @"password" : password,
        // TODO when /?json=1 hits the live forums, redirect there instead to get forum hierarchy
        //      as well as logged-in user's info.
        @"next": @"/member.php?action=getinfo&json=1"
    };
    // Logging in does not work via dev.forums.somethingawful.com, so force production site.
    NSMutableURLRequest *request = [self requestWithMethod:@"POST" path:@"account.php?json=1"
                                                parameters:parameters];
    request.URL = [NSURL URLWithString:@"https://forums.somethingawful.com/account.php?json=1"];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:request
                                                               success:^(id _, NSDictionary *json)
    {
        NSDictionary *userInfo = @{
            @"userID": [json[@"userid"] stringValue],
            @"username": json[@"username"]
        };
        if (callback) callback(nil, userInfo);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error)
    {
        if (operation.response.statusCode == 401) {
            NSDictionary *userInfo = @{
                NSLocalizedDescriptionKey: @"Invalid username or password",
                NSUnderlyingErrorKey: error
            };
            error = [NSError errorWithDomain:AwfulErrorDomain
                                        code:AwfulErrorCodes.badUsernameOrPassword
                                    userInfo:userInfo];
        }
        if (callback) callback(error, nil);
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

- (NSOperation *)locatePostWithID:(NSString *)postID
    andThen:(void (^)(NSError *error, NSString *threadID, AwfulThreadPage page))callback
{
    // The SA Forums will direct a certain URL to the thread with a given post. We'll wait for that
    // redirect, then parse out the info we need.
    NSURLRequest *request = [self requestWithMethod:@"GET" path:@"showthread.php"
                                         parameters:@{ @"goto" : @"post", @"postid" : postID }];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:request
                                                               success:^(id _, id __)
    {
        // Once we have the redirect we want, we cancel the operation. So if this "success" callback
        // gets called, we've actually failed.
        if (callback) callback(nil, nil, 0);
    } failure:^(id _, NSError *error)
    {
        // Once we get the redirect we need, we call the callback then cancel the operation.
        // So there's no need to do anything if we get a "cancelled" error.
        if (!([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled)) {
            if (callback) callback(error, nil, 0);
        }
    }];
    __weak AFHTTPRequestOperation *weakOp = op;
    [op setRedirectResponseBlock:^NSURLRequest *(id _, NSURLRequest *request, NSURLResponse *response)
    {
        AFHTTPRequestOperation *strongOp = weakOp;
        if (!response) return request;
        [strongOp cancel];
        NSDictionary *query = [[request URL] queryDictionary];
        if (callback) {
            dispatch_async(strongOp.successCallbackQueue ?: dispatch_get_main_queue(), ^{
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
    NSDictionary *parameters = @{ @"action": @"getinfo", @"userid": userID, @"json": @1 };
    NSURLRequest *request = [self requestWithMethod:@"GET" path:@"member.php"
                                         parameters:parameters];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:request
                                                               success:^(id op, NSDictionary *json)
    {
        AwfulUser *user = [AwfulUser userCreatedOrUpdatedFromJSON:json];
        if (user.profilePictureURL && [user.profilePictureURL hasPrefix:@"/"]) {
            NSString *base = [self.baseURL absoluteString];
            if (self.usingDevDotForums) {
                NSString * const devPrefix = @"dev.forums.somethingawful.com";
                NSRange approximateHostRange = NSMakeRange([self.baseURL.scheme length],
                                                           [devPrefix length] + 5);
                base = [base stringByReplacingOccurrencesOfString:devPrefix
                                                       withString:@"forums.somethingawful.com"
                                                          options:0
                                                            range:approximateHostRange];
            }
            base = [base substringToIndex:[base length] - 1];
            user.profilePictureURL = [base stringByAppendingString:user.profilePictureURL];
            [[AwfulDataStack sharedDataStack] save];
        }
        if (callback) callback(nil, user);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil);
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

- (NSOperation *)listBansOnPage:(NSInteger)page
                        andThen:(void (^)(NSError *error, NSArray *bans))callback
{
    NSDictionary *parameters = @{ @"pagenumber": @(page) };
    NSURLRequest *request = [self requestWithMethod:@"GET" path:@"banlist.php"
                                         parameters:parameters];
    id op = [self HTTPRequestOperationWithRequest:request
                                          success:^(id _, NSArray *bans)
    {
        if (callback) callback(nil, bans);
    } failure:^(id _, NSError *error) {
        if (callback) callback(error, nil);
    }];
    [op setCreateParsedInfoBlock:^id(NSData *data) {
        return [BanParsedInfo bansWithHTMLData:data];
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

- (NSOperation *)tryAccessingDevDotForumsAndThen:(void (^)(NSError *error, BOOL success))callback
{
    NSURL *url = [NSURL URLWithString:@"http://dev.forums.somethingawful.com/"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"HEAD"];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:request
                                                               success:^(id _, id __)
    {
        if (callback) callback(nil, YES);
    } failure:^(id _, NSError *error) {
        if (callback) callback(error, NO);
    }];
    // The Forums redirects users away from dev.forums if they don't have permission.
    __weak AFHTTPRequestOperation *weakOp = op;
    [op setRedirectResponseBlock:^NSURLRequest *(id _, NSURLRequest *request,
                                                 NSURLResponse *response)
    {
        if (!response) return request;
        AFHTTPRequestOperation *strongOp = weakOp;
        [strongOp cancel];
        if (callback) {
            dispatch_async(strongOp.successCallbackQueue ?: dispatch_get_main_queue(), ^{
                callback(nil, NO);
            });
        }
        return nil;
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

- (NSOperation *)listPrivateMessagesAndThen:(void (^)(NSError *error, NSArray *messages))callback
{
    NSURLRequest *urlRequest = [self requestWithMethod:@"GET" path:@"private.php" parameters:nil];
    id op = [self HTTPRequestOperationWithRequest:urlRequest
                                          success:^(id _, PrivateMessageFolderParsedInfo *info)
    {
        NSArray *messages = [AwfulPrivateMessage privateMessagesWithFolderParsedInfo:info];
        if (callback) callback(nil, messages);
    } failure:^(id _, NSError *error) {
        if (callback) callback(error, nil);
    }];
    [op setCreateParsedInfoBlock:^id(NSData * data) {
        return [[PrivateMessageFolderParsedInfo alloc] initWithHTMLData:data];
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

- (NSOperation *)deletePrivateMessageWithID:(NSString *)messageID
                                    andThen:(void (^)(NSError *error))callback
{
    NSDictionary *parameters = @{
        @"action": @"dodelete",
        @"privatemessageid": messageID,
        @"delete": @"yes"
    };
    NSURLRequest *request = [self requestWithMethod:@"POST" path:@"private.php"
                                         parameters:parameters];
    id op = [self HTTPRequestOperationWithRequest:request success:^(id _, id __) {
        if (callback) callback(nil);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error);
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

- (NSOperation *)readPrivateMessageWithID:(NSString *)messageID
                                  andThen:(void (^)(NSError *error,
                                                    AwfulPrivateMessage *message))callback
{
    NSDictionary *parameters = @{ @"action": @"show", @"privatemessageid": messageID };
    NSURLRequest *urlRequest = [self requestWithMethod:@"GET" path:@"private.php"
                                            parameters:parameters];
    id op = [self HTTPRequestOperationWithRequest:urlRequest
                                          success:^(id _, PrivateMessageParsedInfo *info)
    {
        AwfulPrivateMessage *message = [AwfulPrivateMessage privateMessageWithParsedInfo:info];
        if (callback) callback(nil, message);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil);
    }];
    [op setCreateParsedInfoBlock:^id(NSData *data) {
        return [[PrivateMessageParsedInfo alloc] initWithHTMLData:data];
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

- (NSOperation *)quotePrivateMessageWithID:(NSString *)messageID
                                   andThen:(void (^)(NSError *error, NSString *bbcode))callback
{
    NSDictionary *parameters = @{ @"action": @"newmessage", @"privatemessageid": messageID };
    NSURLRequest *urlRequest = [self requestWithMethod:@"GET" path:@"private.php"
                                            parameters:parameters];
    id op = [self HTTPRequestOperationWithRequest:urlRequest
                                          success:^(id _, ComposePrivateMessageParsedInfo *info)
    {
        if (callback) callback(nil, info.text);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil);
    }];
    [op setCreateParsedInfoBlock:^id(NSData *data) {
        return [[ComposePrivateMessageParsedInfo alloc] initWithHTMLData:data];
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

- (NSOperation *)listAvailablePrivateMessagePostIconsAndThen:(void (^)(NSError *error, NSDictionary *postIcons, NSArray *postIconIDs))callback
{
    NSURLRequest *urlRequest = [self requestWithMethod:@"GET" path:@"private.php"
                                            parameters:@{ @"action": @"newmessage" }];
    id op = [self HTTPRequestOperationWithRequest:urlRequest
                                          success:^(id _, ComposePrivateMessageParsedInfo *info)
    {
        if (callback) callback(nil, info.postIcons, info.postIconIDs);
    } failure:^(id _, NSError *error) {
        if (callback) callback(error, nil, nil);
    }];
    [op setCreateParsedInfoBlock:^id(NSData *data) {
        return [[ComposePrivateMessageParsedInfo alloc] initWithHTMLData:data];
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

- (NSOperation *)sendPrivateMessageTo:(NSString *)username
                              subject:(NSString *)subject
                                 icon:(NSString *)iconID
                                 text:(NSString *)text
               asReplyToMessageWithID:(NSString *)replyMessageID
           forwardedFromMessageWithID:(NSString *)forwardMessageID
                              andThen:(void (^)(NSError *error,
                                                AwfulPrivateMessage *message))callback
{
    NSMutableDictionary *parameters = [@{
        @"touser": username,
        @"title": subject,
        @"iconid": iconID ?: @"0",
        @"message": text,
        @"action": @"dosend",
        @"forward": forwardMessageID ? @"true" : @"",
        @"submit": @"Send Message",
    } mutableCopy];
    if (replyMessageID || forwardMessageID) {
        parameters[@"prevmessageid"] = replyMessageID ?: forwardMessageID;
    }
    NSURLRequest *urlRequest = [self requestWithMethod:@"POST" path:@"private.php"
                                            parameters:parameters];
    id op = [self HTTPRequestOperationWithRequest:urlRequest
                                          success:^(id _, id __)
    {
        // TODO parse response if that makes sense (e.g. user can't receive messages or unknown user)
        // TODO return message
        if (callback) callback(nil, nil);
    } failure:^(id _, NSError *error) {
        if (callback) callback(error, nil);
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

@end


NSString * const AwfulErrorDomain = @"AwfulErrorDomain";

const struct AwfulErrorCodes AwfulErrorCodes = {
    .badUsernameOrPassword = -1000,
    .threadIsClosed = -1001,
    .parseError = -1002,
};
