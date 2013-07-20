//
//  AwfulHTTPClient.m
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import "AwfulHTTPClient.h"
#import "AwfulAppDelegate.h"
#import "AwfulDataStack.h"
#import "AwfulErrorDomain.h"
#import "AwfulJSONOrScrapeOperation.h"
#import "AwfulModels.h"
#import "AwfulParsing.h"
#import "AwfulSettings.h"
#import "AwfulThreadTag.h"
#import "NSManagedObject+Awful.h"
#import "NSURL+QueryDictionary.h"

@interface AwfulHTTPClient ()

@property (getter=isReachable, nonatomic) BOOL reachable;

@end


@implementation AwfulHTTPClient

static AwfulHTTPClient *instance = nil;

+ (AwfulHTTPClient *)client
{
    @synchronized([AwfulHTTPClient class]) {
        if (!instance) {
            NSString *urlString = [AwfulSettings settings].customBaseURL;
            if (urlString) {
                NSURL *url = [NSURL URLWithString:urlString];
                if (!url.scheme) {
                    urlString = [NSString stringWithFormat:@"http://%@", urlString];
                }
            } else {
                urlString = @"http://forums.somethingawful.com/";
            }
            instance = [[AwfulHTTPClient alloc] initWithBaseURL:[NSURL URLWithString:urlString]];
        }
    }
    return instance;
}

+ (void)reset
{
    // Clear the singleton instance so it's recreated on next access.
    // Not synchronizing; I don't really care if some last thread gets the old client.
    instance = nil;
}

+ (void)initialize
{
    if (self != [AwfulHTTPClient class]) return;
    NSNotificationCenter *noteCenter = [NSNotificationCenter defaultCenter];
    [noteCenter addObserver:self selector:@selector(settingsDidChange:)
                       name:AwfulSettingsDidChangeNotification object:nil];
    [noteCenter addObserver:self selector:@selector(didLogOut:)
                       name:AwfulUserDidLogOutNotification object:nil];
}

+ (void)settingsDidChange:(NSNotification *)note
{
    NSArray *keys = note.userInfo[AwfulSettingsDidChangeSettingsKey];
    if ([keys containsObject:AwfulSettingsKeys.customBaseURL]) {
        [self reset];
    }
}

+ (void)didLogOut:(NSNotification *)note
{
    [self reset];
}

- (BOOL)isLoggedIn
{
    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:self.baseURL];
    return [[cookies valueForKey:NSHTTPCookieName] containsObject:@"bbuserid"];
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
        
        // When a user changes their password, subsequent HTTP operations will come back without a
        // login cookie. So any operation might bear the news that we've been logged out.
        NSNotificationCenter *noteCenter = [NSNotificationCenter defaultCenter];
        [noteCenter addObserver:self selector:@selector(networkingOperationDidStart:)
                           name:AFNetworkingOperationDidStartNotification object:nil];
    }
    return self;
}

- (void)networkingOperationDidStart:(NSNotification *)note
{
    // Only subscribe for notifications if we're logged in.
    if (!self.loggedIn) return;
    AFURLConnectionOperation *op = note.object;
    if (![op.request.URL.absoluteString hasPrefix:self.baseURL.absoluteString]) return;
    NSNotificationCenter *noteCenter = [NSNotificationCenter defaultCenter];
    [noteCenter addObserver:self selector:@selector(networkingOperationDidFinish:)
                       name:AFNetworkingOperationDidFinishNotification object:op];
}

- (void)networkingOperationDidFinish:(NSNotification *)note
{
    AFHTTPRequestOperation *op = note.object;
    NSNotificationCenter *noteCenter = [NSNotificationCenter defaultCenter];
    [noteCenter removeObserver:self name:AFNetworkingOperationDidFinishNotification object:op];
    if (![op isKindOfClass:[AFHTTPRequestOperation class]]) return;
    
    // We only subscribed for this notification if we were logged in at the time. If we aren't
    // logged in now, the cookies changed, and we need to finish logging out.
    if (op.hasAcceptableStatusCode && !self.loggedIn) {
        [[AwfulAppDelegate instance] logOut];
    }
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSOperation *)listThreadsInForumWithID:(NSString *)forumID
                                   onPage:(NSInteger)page
                                  andThen:(void (^)(NSError *error, NSArray *threads))callback
{
    NSDictionary *parameters = @{
        @"forumid": forumID,
        @"perpage": @40,
        @"pagenumber": @(page),
    };
    NSURLRequest *request = [self requestWithMethod:@"GET" path:@"forumdisplay.php"
                                         parameters:parameters];
    id op = [self HTTPRequestOperationWithRequest:request
                                          success:^(id _, id responseObject)
    {
        NSArray *threads = [AwfulThread threadsCreatedOrUpdatedWithParsedInfo:responseObject];
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
    NSDictionary *parameters = @{
        @"action": @"view",
        @"perpage": @40,
        @"pagenumber": @(page),
    };
    NSURLRequest *request = [self requestWithMethod:@"GET" path:@"bookmarkthreads.php"
                                         parameters:parameters];
    id op = [self HTTPRequestOperationWithRequest:request
                                          success:^(id _, id responseObject)
    {
        NSArray *threads = [AwfulThread threadsCreatedOrUpdatedWithParsedInfo:responseObject];
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
                            singleUserID:(NSString *)singleUserID
                                 andThen:(void (^)(NSError *error,
                                                   NSArray *posts,
                                                   NSUInteger firstUnreadPost,
                                                   NSString *advertisementHTML))callback
{
    NSMutableDictionary *parameters = [@{
        @"threadid": threadID,
        @"perpage": @40,
    } mutableCopy];
    if (page == AwfulThreadPageNextUnread) parameters[@"goto"] = @"newpost";
    else if (page == AwfulThreadPageLast) parameters[@"goto"] = @"lastpost";
    else parameters[@"pagenumber"] = @(page);
    
    if (singleUserID) parameters[@"userid"] = singleUserID;
    
    NSURLRequest *request = [self requestWithMethod:@"GET" path:@"showthread.php"
                                         parameters:parameters];
    id op = [self HTTPRequestOperationWithRequest:request
                                          success:^(id op, id responseObject)
    {
        PageParsedInfo *pageInfo = responseObject;
        pageInfo.singleUserID = singleUserID;
        NSArray *posts = [AwfulPost postsCreatedOrUpdatedFromPageInfo:responseObject];
        NSString *ad = [responseObject advertisementHTML];
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
            @"message" : PreparePostText(text),
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
        } failure:^(id _, NSError *error) {
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

static NSString * PreparePostText(NSString *noEntities)
{
    // Replace all characters outside windows-1252 with XML entities.
    noEntities = [noEntities precomposedStringWithCanonicalMapping];
    NSMutableString *withEntities = [noEntities mutableCopy];
    NSError *error;
    NSString *pattern = @"(?x)[^ \\u0000-\\u007F \\u20AC \\u201A \\u0192 \\u201E \\u2026 \\u2020 "
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
        if (!callback) return;
        // If you quote a post from a thread that's been moved to the Gas Chamber, you don't get a
        // post body. That's an error, even though the HTTP operation succeeded.
        if (json[@"body"]) {
            callback(nil, json[@"body"]);
        } else {
            NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: @"Missing quoted post body" };
            NSError *error = [NSError errorWithDomain:AwfulErrorDomain
                                                 code:AwfulErrorCodes.parseError
                                             userInfo:userInfo];
            callback(error, nil);
        }
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
             @"message": PreparePostText(text)
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
        @"next": @"/member.php?action=getinfo&json=1"
    };
    NSURLRequest *request = [self requestWithMethod:@"POST" path:@"account.php?json=1"
                                         parameters:parameters];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:request
                                                               success:^(id _, NSDictionary *json)
    {
        if (!json[@"userid"] || !json[@"username"] || !json[@"receivepm"]) {
            if (callback) {
                NSString *message = @"Could not parse user info";
                NSError *error = [NSError errorWithDomain:AwfulErrorDomain
                                                     code:AwfulErrorCodes.parseError
                                                 userInfo:@{ NSLocalizedDescriptionKey: message }];
                callback(error, nil);
            }
            // Don't want this failed login attempt to be taken as successful.
            NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
            for (NSHTTPCookie *cookie in [cookieStorage cookies]) {
                [cookieStorage deleteCookie:cookie];
            }
            return;
        }
        NSString *username = json[@"username"];
        if (![username isKindOfClass:[NSString class]] &&
            [username respondsToSelector:@selector(stringValue)])
        {
            username = [(id)username stringValue];
        }
        NSDictionary *userInfo = @{
            @"userID": [json[@"userid"] stringValue],
            @"username": username,
            @"canSendPrivateMessages": json[@"receivepm"],
        };
        [[NSNotificationCenter defaultCenter] postNotificationName:AwfulUserDidLogInNotification
                                                            object:nil];
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

NSString * const AwfulUserDidLogInNotification = @"com.awfulapp.Awful.UserDidLogInNotification";

- (NSOperation *)locatePostWithID:(NSString *)postID
andThen:(void (^)(NSError *error, NSString *threadID, AwfulThreadPage page))callback
{
    // The SA Forums will direct a certain URL to the thread with a given post. We'll wait for that
    // redirect, then parse out the info we need.
    NSURLRequest *request = [self requestWithMethod:@"GET" path:@"showthread.php"
                                         parameters:@{ @"goto" : @"post", @"postid" : postID }];
    __block BOOL didSucceed = NO;
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:request
                                                               success:^(id _, id __)
    {
        // Once we have the redirect we want, we cancel the operation. So if this "success" callback
        // gets called, we've actually failed.
        if (callback) {
            NSString *message = @"The post could not be found";
            NSError *error = [NSError errorWithDomain:AwfulErrorDomain
                                                 code:AwfulErrorCodes.parseError
                                             userInfo:@{ NSLocalizedDescriptionKey: message }];
            callback(error, nil, 0);
        }
    } failure:^(AFHTTPRequestOperation *op, NSError *error) {
        if (!didSucceed) {
            if (callback) callback(error, nil, 0);
        }
    }];
    __weak AFHTTPRequestOperation *weakOp = op;
    [op setRedirectResponseBlock:^NSURLRequest *(id _, NSURLRequest *request,
                                                 NSURLResponse *response)
    {
        AFHTTPRequestOperation *strongOp = weakOp;
        didSucceed = YES;
        if (!response) return request;
        [strongOp cancel];
        if (!callback) return nil;
        NSDictionary *query = [request.URL queryDictionary];
        if ([query[@"threadid"] length] > 0 && [query[@"pagenumber"] integerValue] != 0) {
            dispatch_async(strongOp.successCallbackQueue ?: dispatch_get_main_queue(), ^{
                callback(nil, query[@"threadid"], [query[@"pagenumber"] integerValue]);
            });
        } else {
            NSDictionary *query = [request.URL queryDictionary];
            NSString *missingInfo = query[@"threadid"] ? @"page number" : @"thread ID";
            NSString *message = [NSString stringWithFormat:@"The %@ could not be found",
                                 missingInfo];
            NSError *error = [NSError errorWithDomain:AwfulErrorDomain
                                                 code:AwfulErrorCodes.parseError
                                             userInfo:@{ NSLocalizedDescriptionKey: message }];
            dispatch_async(strongOp.failureCallbackQueue ?: dispatch_get_main_queue(), ^{
                callback(error, nil, 0);
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
            base = [base substringToIndex:[base length] - 1];
            user.profilePictureURL = [base stringByAppendingString:user.profilePictureURL];
        }
        [[AwfulDataStack sharedDataStack] save];
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

- (NSOperation *)listPrivateMessagesAndThen:(void (^)(NSError *error, NSArray *messages))callback
{
    NSURLRequest *urlRequest = [self requestWithMethod:@"GET" path:@"private.php" parameters:nil];
    id op = [self HTTPRequestOperationWithRequest:urlRequest
                                          success:^(id _, PrivateMessageFolderParsedInfo *info)
    {
        NSArray *messages = [AwfulPrivateMessage privateMessagesWithFolderParsedInfo:info];
        [AwfulPrivateMessage deleteAllMatchingPredicate:@"NOT(self IN %@)", messages];
        [[AwfulDataStack sharedDataStack] save];
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

- (NSOperation *)listAvailablePrivateMessagePostIconsAndThen:(void (^)(NSError *error,
                                                                       NSArray *postIcons))callback
{
    NSURLRequest *urlRequest = [self requestWithMethod:@"GET" path:@"private.php"
                                            parameters:@{ @"action": @"newmessage" }];
    id op = [self HTTPRequestOperationWithRequest:urlRequest
                                          success:^(id _, ComposePrivateMessageParsedInfo *info)
    {
        if (callback) callback(nil, CollectPostIcons(info.postIconIDs, info.postIcons));
    } failure:^(id _, NSError *error) {
        if (callback) callback(error, nil);
    }];
    [op setCreateParsedInfoBlock:^id(NSData *data) {
        return [[ComposePrivateMessageParsedInfo alloc] initWithHTMLData:data];
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

static NSArray * CollectPostIcons(NSArray *postIconIDs, NSDictionary *postIcons)
{
    if ([postIconIDs count] == 0) return nil;
    NSMutableArray *collection = [NSMutableArray new];
    for (NSString *iconID in postIconIDs) {
        AwfulThreadTag *tag = [AwfulThreadTag new];
        tag.composeID = iconID;
        tag.imageName = [[postIcons[iconID] lastPathComponent] stringByDeletingPathExtension];
        [collection addObject:tag];
    }
    return collection;
}

- (NSOperation *)sendPrivateMessageTo:(NSString *)username
                              subject:(NSString *)subject
                                 icon:(NSString *)iconID
                                 text:(NSString *)text
               asReplyToMessageWithID:(NSString *)replyMessageID
           forwardedFromMessageWithID:(NSString *)forwardMessageID
                              andThen:(void (^)(NSError *error))callback
{
    NSMutableDictionary *parameters = [@{
        @"touser": username,
        @"title": subject,
        @"iconid": iconID ?: @"0",
        @"message": text,
        @"action": @"dosend",
        @"forward": forwardMessageID ? @"true" : @"",
        @"savecopy": @"yes",
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
        // TODO parse response if that makes sense (e.g. user can't receive messages or unknown
        //      user)
        if (callback) callback(nil);
    } failure:^(id _, NSError *error) {
        if (callback) callback(error);
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

- (NSOperation *)listAvailablePostIconsForForumWithID:(NSString *)forumID
                                              andThen:(void (^)(NSError *error,
                                                                NSArray *postIcons,
                                                                NSArray *secondaryPostIcons,
                                                                NSString *secondaryIconKey
                                                                ))callback
{
    NSDictionary *parameters = @{ @"action": @"newthread", @"forumid": forumID };
    NSURLRequest *request = [self requestWithMethod:@"GET" path:@"newthread.php"
                                         parameters:parameters];
    id op = [self HTTPRequestOperationWithRequest:request
                                          success:^(id _, ComposePrivateMessageParsedInfo *info)
    {
        if (callback) callback(nil, CollectPostIcons(info.postIconIDs, info.postIcons),
                               CollectPostIcons(info.secondaryIconIDs, info.secondaryIcons),
                               info.secondaryIconKey);
    } failure:^(id _, NSError *error) {
        if (callback) callback(error, nil, nil, nil);
    }];
    [op setCreateParsedInfoBlock:^id(NSData *data) {
        return [[ComposePrivateMessageParsedInfo alloc] initWithHTMLData:data];
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

- (NSOperation *)postThreadInForumWithID:(NSString *)forumID
                                 subject:(NSString *)subject
                                    icon:(NSString *)iconID
                           secondaryIcon:(NSString *)secondaryIconID
                        secondaryIconKey:(NSString *)secondaryIconKey
                                    text:(NSString *)text
                                 andThen:(void (^)(NSError *error, NSString *threadID))callback
{
    NSParameterAssert([forumID length] > 0);
    NSParameterAssert([subject length] > 0);
    NSParameterAssert([text length] > 0);
    
    NSDictionary *parameters = @{ @"action": @"newthread", @"forumid": forumID };
    NSURLRequest *request = [self requestWithMethod:@"GET" path:@"newthread.php"
                                         parameters:parameters];
    id op = [self HTTPRequestOperationWithRequest:request
                                          success:^(id _, NewThreadFormParsedInfo *info)
    {
        NSMutableDictionary *postParameters = [@{
            @"forumid": forumID,
            @"action": @"postthread",
            @"formkey": info.formkey,
            @"form_cookie": info.formCookie,
            // I'm not sure if the subject needs any particular escapes, or what's allowed. This
            // is a total guess.
            @"subject": PreparePostText(subject),
            @"iconid": iconID ?: @"0",
            @"message": PreparePostText(text),
            @"polloptions": @"4",
            @"submit": @"Submit New Thread",
        } mutableCopy];
        if ([secondaryIconID length] > 0 && [secondaryIconKey length] > 0) {
            postParameters[secondaryIconKey] = secondaryIconID;
        }
        if (info.automaticallyParseURLs) {
            postParameters[@"parseurl"] = info.automaticallyParseURLs;
        }
        if (info.bookmarkThread) {
            postParameters[@"bookmark"] = info.bookmarkThread;
        }
        NSURLRequest *postRequest = [self requestWithMethod:@"POST" path:@"newthread.php"
                                                 parameters:postParameters];
        id postOp = [self HTTPRequestOperationWithRequest:postRequest
                                                  success:^(id _, SuccessfulNewThreadParsedInfo *info)
        {
            if (callback) callback(nil, info.threadID);
        } failure:^(id _, NSError *error) {
            if (callback) callback(error, nil);
        }];
        [postOp setCreateParsedInfoBlock:^id(NSData *data) {
            return [[SuccessfulNewThreadParsedInfo alloc] initWithHTMLData:data];
        }];
        [self enqueueHTTPRequestOperation:postOp];
    } failure:^(id _, NSError *error) {
        if (callback) callback(error, nil);
    }];
    [op setCreateParsedInfoBlock:^id(NSData *data) {
        return [[NewThreadFormParsedInfo alloc] initWithHTMLData:data];
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

#pragma mark - AFHTTPClient

- (AFHTTPRequestOperation *)HTTPRequestOperationWithRequest:(NSURLRequest *)urlRequest
                                                    success:(void (^)(AFHTTPRequestOperation *, id))success
                                                    failure:(void (^)(AFHTTPRequestOperation *, NSError *))failure
{
    // NSURLConnection will, absent relevant HTTP headers, cache responses for an unknown and
    // unfortunately long time. http://blackpixel.com/blog/2012/05/caching-and-nsurlconnection.html
    // This came up when using Awful from some public wi-fi that redirected to a login page. Six
    // hours and a different network later, the same login page was being served up from the cache.
    AFHTTPRequestOperation *op = [super HTTPRequestOperationWithRequest:urlRequest
                                                                success:success failure:failure];
    if ([[urlRequest HTTPMethod] compare:@"GET" options:NSCaseInsensitiveSearch] == NSOrderedSame) {
        [op setCacheResponseBlock:^NSCachedURLResponse *(NSURLConnection *connection, NSCachedURLResponse *cachedResponse) {
            if ([connection currentRequest].cachePolicy == NSURLRequestUseProtocolCachePolicy) {
                NSHTTPURLResponse *response = (id)[cachedResponse response];
                NSDictionary *headers = [response allHeaderFields];
                if (!(headers[@"Cache-Control"] || headers[@"Expires"])) {
                    NSLog(@"refusing to cache response to %@", urlRequest.URL);
                    return nil;
                }
            }
            return cachedResponse;
        }];
    }
    return op;
}

@end
