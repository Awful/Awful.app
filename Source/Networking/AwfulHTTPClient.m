//  AwfulHTTPClient.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulHTTPClient.h"
#import <AFNetworking/AFNetworking.h>
#import "AwfulAppDelegate.h"
#import "AwfulErrorDomain.h"
#import "AwfulHTMLResponseSerializer.h"
#import "AwfulModels.h"
#import "AwfulParsedInfoResponseSerializer.h"
#import "AwfulParsing.h"
#import "AwfulSettings.h"
#import "AwfulThreadListScraper.h"
#import "AwfulThreadTag.h"
#import "AwfulUIKitAndFoundationCategories.h"

@interface AwfulHTTPRequestOperationManager : AFHTTPRequestOperationManager

- (AFHTTPRequestOperation *)GET:(NSString *)URLString
                     parameters:(NSDictionary *)parameters
               parsingWithBlock:(id (^)(NSData *data))parseBlock
                        success:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success
                        failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure;

- (AFHTTPRequestOperation *)POST:(NSString *)URLString
                      parameters:(NSDictionary *)parameters
                parsingWithBlock:(id (^)(NSData *data))parseBlock
                         success:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success
                         failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure;

- (AFHTTPRequestOperation *)HTMLGET:(NSString *)URLString
                         parameters:(NSDictionary *)parameters
                            success:(void (^)(AFHTTPRequestOperation *, id))success
                            failure:(void (^)(AFHTTPRequestOperation *, NSError *))failure;

@end

@implementation AwfulHTTPClient
{
    AwfulHTTPRequestOperationManager *_HTTPManager;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (id)init
{
    if (!(self = [super init])) return nil;
    [self reset];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(settingsDidChange:)
                                                 name:AwfulSettingsDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didLogOut:)
                                                 name:AwfulUserDidLogOutNotification
                                               object:nil];
    
    // When a user changes their password, subsequent HTTP operations will come back without a login cookie. So any operation might bear the news that we've been logged out.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(networkingOperationDidStart:)
                                                 name:AFNetworkingOperationDidStartNotification
                                               object:nil];
    return self;
}

+ (AwfulHTTPClient *)client
{
    static AwfulHTTPClient *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [AwfulHTTPClient new];
    });
    return instance;
}

- (void)reset
{
    NSString *urlString = [AwfulSettings settings].customBaseURL;
    if (urlString) {
        NSURL *url = [NSURL URLWithString:urlString];
        if (!url.scheme) {
            urlString = [NSString stringWithFormat:@"http://%@", urlString];
        }
    } else {
        urlString = @"http://forums.somethingawful.com/";
    }
    _HTTPManager = [[AwfulHTTPRequestOperationManager alloc] initWithBaseURL:[NSURL URLWithString:urlString]];
    NSArray *serializers = @[ [AFJSONResponseSerializer new],
                              [AFHTTPResponseSerializer new] ];
    _HTTPManager.responseSerializer = [AFCompoundResponseSerializer compoundSerializerWithResponseSerializers:serializers];
}

- (void)settingsDidChange:(NSNotification *)note
{
    NSArray *keys = note.userInfo[AwfulSettingsDidChangeSettingsKey];
    if ([keys containsObject:AwfulSettingsKeys.customBaseURL]) {
        [self reset];
    }
}

- (void)didLogOut:(NSNotification *)note
{
    [self reset];
}

- (BOOL)isReachable
{
    return _HTTPManager.reachabilityManager.reachable;
}

- (BOOL)isLoggedIn
{
    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:_HTTPManager.baseURL];
    return [[cookies valueForKey:NSHTTPCookieName] containsObject:@"bbuserid"];
}

- (void)networkingOperationDidStart:(NSNotification *)note
{
    // Only subscribe for notifications if we're logged in.
    if (!self.loggedIn) return;
    AFURLConnectionOperation *op = note.object;
    if (![op.request.URL.absoluteString hasPrefix:_HTTPManager.baseURL.absoluteString]) return;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(networkingOperationDidFinish:)
                                                 name:AFNetworkingOperationDidFinishNotification
                                               object:op];
}

- (void)networkingOperationDidFinish:(NSNotification *)note
{
    AFHTTPRequestOperation *op = note.object;
    NSNotificationCenter *noteCenter = [NSNotificationCenter defaultCenter];
    [noteCenter removeObserver:self name:AFNetworkingOperationDidFinishNotification object:op];
    if (![op isKindOfClass:[AFHTTPRequestOperation class]]) return;
    
    // We only subscribed for this notification if we were logged in at the time. If we aren't logged in now, the cookies changed, and we need to finish logging out.
    if (!op.error && !self.loggedIn) {
        [[AwfulAppDelegate instance] logOut];
    }
}

- (NSOperation *)listThreadsInForum:(AwfulForum *)forum
                             onPage:(NSInteger)page
                            andThen:(void (^)(NSError *error, NSArray *threads))callback
{
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    return [_HTTPManager HTMLGET:@"forumdisplay.php"
                      parameters:@{ @"forumid": forum.forumID,
                                    @"perpage": @40,
                                    @"pagenumber": @(page) }
                         success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        [managedObjectContext performBlock:^{
            AwfulThreadListScraper *scraper = [AwfulThreadListScraper new];
            NSError *error;
            NSArray *threads = [scraper scrapeDocument:document
                                               fromURL:operation.response.URL
                              intoManagedObjectContext:managedObjectContext
                                                 error:&error];
            if (callback) {
                dispatch_async(operation.completionQueue ?: dispatch_get_main_queue(), ^{
                    callback(error, threads);
                });
            }
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil);
    }];
}

- (NSOperation *)listBookmarkedThreadsOnPage:(NSInteger)page
                                     andThen:(void (^)(NSError *error, NSArray *threads))callback
{
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    return [_HTTPManager HTMLGET:@"bookmarkthreads.php"
                      parameters:@{ @"action": @"view",
                                    @"perpage": @40,
                                    @"pagenumber": @(page) }
                         success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        [managedObjectContext performBlock:^{
            AwfulThreadListScraper *scraper = [AwfulThreadListScraper new];
            NSError *error;
            NSArray *threads = [scraper scrapeDocument:document
                                               fromURL:operation.response.URL
                              intoManagedObjectContext:managedObjectContext
                                                 error:&error];
            if (callback) {
                dispatch_async(operation.completionQueue ?: dispatch_get_main_queue(), ^{
                    callback(error, threads);
                });
            }
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil);
    }];
}

- (NSOperation *)listPostsInThreadWithID:(NSString *)threadID
                                  onPage:(AwfulThreadPage)page
                            singleUserID:(NSString *)singleUserID
                                 andThen:(void (^)(NSError *error,
                                                   NSArray *posts,
                                                   NSUInteger firstUnreadPost,
                                                   NSString *advertisementHTML))callback
{
    NSMutableDictionary *parameters = [@{ @"threadid": threadID,
                                          @"perpage": @40 } mutableCopy];
    if (page == AwfulThreadPageNextUnread) {
        parameters[@"goto"] = @"newpost";
    } else if (page == AwfulThreadPageLast) {
        parameters[@"goto"] = @"lastpost";
    } else {
        parameters[@"pagenumber"] = @(page);
    }
    if (singleUserID) {
        parameters[@"userid"] = singleUserID;
    }
    return [_HTTPManager GET:@"showthread.php"
                  parameters:parameters
            parsingWithBlock:^id(NSData *data) {
                return [[PageParsedInfo alloc] initWithHTMLData:data];
            } success:^(AFHTTPRequestOperation *operation, PageParsedInfo *pageInfo) {
                pageInfo.singleUserID = singleUserID;
                NSArray *posts = [AwfulPost postsCreatedOrUpdatedFromPageInfo:pageInfo
                                                       inManagedObjectContext:self.managedObjectContext];
                NSString *ad = [pageInfo advertisementHTML];
                if (callback) {
                    NSInteger firstUnreadPost = NSNotFound;
                    if (page == AwfulThreadPageNextUnread) {
                        NSString *fragment = operation.response.URL.fragment;
                        if ([fragment hasPrefix:@"pti"]) {
                            firstUnreadPost = [[fragment substringFromIndex:3] integerValue] - 1;
                            if (firstUnreadPost < 0) {
                                firstUnreadPost = NSNotFound;
                            }
                        }
                    }
                    callback(nil, posts, firstUnreadPost, ad);
                }
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                if (callback) callback(error, nil, NSNotFound, nil);
            }];
}

- (NSOperation *)learnUserInfoAndThen:(void (^)(NSError *error, NSDictionary *userInfo))callback
{
    return [_HTTPManager GET:@"member.php"
                  parameters:@{ @"action": @"getinfo" }
            parsingWithBlock:^(NSData *data) {
                return [[ProfileParsedInfo alloc] initWithHTMLData:data];
            } success:^(AFHTTPRequestOperation *operation, ProfileParsedInfo *parsedInfo) {
                if (callback) {
                    callback(nil, @{ @"userID": parsedInfo.userID,
                                     @"username": parsedInfo.username,
                                     @"canSendPrivateMessages": @(parsedInfo.hasPlatinum) });
                }
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                if (callback) callback(error, nil);
            }];
}

- (NSOperation *)setThreadWithID:(NSString *)threadID
                    isBookmarked:(BOOL)isBookmarked
                         andThen:(void (^)(NSError *error))callback
{
    return [_HTTPManager POST:@"bookmarkthreads.php"
                   parameters:@{ @"json": @"1",
                                 @"action": isBookmarked ? @"add" : @"remove",
                                 @"threadid": threadID }
                      success:^(AFHTTPRequestOperation *operation, id responseObject) {
                          AwfulThread *thread = [AwfulThread fetchArbitraryInManagedObjectContext:self.managedObjectContext
                                                                          matchingPredicateFormat:@"threadID = %@", threadID];
                          thread.bookmarked = isBookmarked;
                          if (callback) callback(nil);
                      } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                          if (callback) callback(error);
                      }];
}

- (NSOperation *)listForumsAndThen:(void (^)(NSError *error, NSArray *forums))callback
{
    // Seems like only forumdisplay.php and showthread.php have the <select> with a complete list of forums. We'll use the Main "forum" as it's the smallest page with the drop-down list.
    return [_HTTPManager GET:@"forumdisplay.php"
                  parameters:@{ @"forumid": @"48" }
            parsingWithBlock:^(NSData *data) {
                return [[ForumHierarchyParsedInfo alloc] initWithHTMLData:data];
            } success:^(AFHTTPRequestOperation *operation, ForumHierarchyParsedInfo *parsedInfo) {
                NSArray *forums = [AwfulForum updateCategoriesAndForums:parsedInfo
                                                 inManagedObjectContext:self.managedObjectContext];
                if (callback) callback(nil, forums);
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                if (callback) callback(error, nil);
            }];
}

- (NSOperation *)replyToThreadWithID:(NSString *)threadID
                                text:(NSString *)text
                             andThen:(void (^)(NSError *error, NSString *postID))callback
{
    return [_HTTPManager GET:@"newreply.php"
                  parameters:@{ @"action" : @"newreply",
                                @"threadid" : threadID }
            parsingWithBlock:^(NSData *data) {
                return [[ReplyFormParsedInfo alloc] initWithHTMLData:data];
            } success:^(AFHTTPRequestOperation *operation, ReplyFormParsedInfo *formInfo) {
                if (!(formInfo.formkey && formInfo.formCookie)) {
                    NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : @"Thread is closed" };
                    NSError *error = [NSError errorWithDomain:AwfulErrorDomain
                                                         code:AwfulErrorCodes.threadIsClosed
                                                     userInfo:userInfo];
                    if (callback) callback(error, nil);
                    return;
                }
                NSMutableDictionary *postParameters = [@{ @"threadid" : threadID,
                                                          @"formkey" : formInfo.formkey,
                                                          @"form_cookie" : formInfo.formCookie,
                                                          @"action" : @"postreply",
                                                          @"message" : PreparePostText(text),
                                                          @"parseurl" : @"yes",
                                                          @"submit" : @"Submit Reply" } mutableCopy];
                if (formInfo.bookmark) {
                    postParameters[@"bookmark"] = formInfo.bookmark;
                }
                [_HTTPManager POST:@"newreply.php"
                        parameters:postParameters
                  parsingWithBlock:^id(NSData *data) {
                      return [[SuccessfulReplyInfo alloc] initWithHTMLData:data];
                  } success:^(AFHTTPRequestOperation *operation, SuccessfulReplyInfo *replyInfo) {
                      NSString *postID = replyInfo.lastPage ? nil : replyInfo.postID;
                      if (callback) callback(nil, postID);
                  } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                      if (callback) callback(error, nil);
                  }];
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                if (callback) callback(error, nil);
            }];
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
    return [_HTTPManager GET:@"editpost.php"
                  parameters:@{ @"action": @"editpost",
                                @"postid": postID }
            parsingWithBlock:^(NSData *data) {
                return [[ReplyFormParsedInfo alloc] initWithHTMLData:data];
            } success:^(AFHTTPRequestOperation *operation, ReplyFormParsedInfo *formInfo) {
                if (callback) callback(nil, formInfo.text);
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                if (callback) callback(error, nil);
            }];
}

- (NSOperation *)quoteTextOfPostWithID:(NSString *)postID
                               andThen:(void (^)(NSError *error, NSString *quotedText))callback
{
    return [_HTTPManager GET:@"newreply.php"
                  parameters:@{ @"action": @"newreply",
                                @"postid": postID,
                                @"json": @1 }
                     success:^(AFHTTPRequestOperation *operation, NSDictionary *json) {
                         if (!callback) return;
                         // If you quote a post from a thread that's been moved to the Gas Chamber, you don't get a post body. That's an error, even though the HTTP operation succeeded.
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
}

- (NSOperation *)editPostWithID:(NSString *)postID
                           text:(NSString *)text
                        andThen:(void (^)(NSError *error))callback
{
    return [_HTTPManager GET:@"editpost.php"
                  parameters:@{ @"action": @"editpost",
                                @"postid": postID }
            parsingWithBlock:^(NSData *data) {
                return [[ReplyFormParsedInfo alloc] initWithHTMLData:data];
            } success:^(AFHTTPRequestOperation *operation, ReplyFormParsedInfo *formInfo) {
                NSMutableDictionary *parameters = [@{ @"action": @"updatepost",
                                                      @"submit": @"Save Changes",
                                                      @"postid": postID,
                                                      @"message": PreparePostText(text) } mutableCopy];
                if (formInfo.bookmark) {
                    parameters[@"bookmark"] = formInfo.bookmark;
                }
                [_HTTPManager POST:@"editpost.php"
                        parameters:parameters
                           success:^(AFHTTPRequestOperation *operation, id responseObject) {
                               if (callback) callback(nil);
                           } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                               if (callback) callback(error);
                           }];
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                if (callback) callback(error);
            }];
}

- (NSOperation *)rateThreadWithID:(NSString *)threadID
                           rating:(NSInteger)rating
                          andThen:(void (^)(NSError *error))callback
{
    return [_HTTPManager POST:@"threadrate.php"
                   parameters:@{ @"vote": @(MAX(5, MIN(1, rating))),
                                 @"threadid": threadID }
                      success:^(AFHTTPRequestOperation *operation, id responseObject) {
                          if (callback) callback(nil);
                      } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                          if (callback) callback(error);
                      }];
}

- (NSOperation *)markThreadWithID:(NSString *)threadID
              readUpToPostAtIndex:(NSString *)index
                          andThen:(void (^)(NSError *error))callback
{
    return [_HTTPManager GET:@"showthread.php"
                  parameters:@{ @"action": @"setseen",
                                @"threadid": threadID,
                                @"index": index }
                     success:^(AFHTTPRequestOperation *operation, id responseObject) {
                         if (callback) callback(nil);
                     } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                         if (callback) callback(error);
                     }];
}

- (NSOperation *)forgetReadPostsInThreadWithID:(NSString *)threadID
                                       andThen:(void (^)(NSError *error))callback
{
    return [_HTTPManager POST:@"showthread.php"
                   parameters:@{ @"threadid": threadID,
                                 @"action": @"resetseen",
                                 @"json": @"1" }
                      success:^(AFHTTPRequestOperation *operation, id responseObject) {
                          if (callback) callback(nil);
                      } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                          if (callback) callback(error);
                      }];
}

- (NSOperation *)logInAsUsername:(NSString *)username
                    withPassword:(NSString *)password
                         andThen:(void (^)(NSError *error, NSDictionary *userInfo))callback
{
    return [_HTTPManager POST:@"account.php?json=1"
                   parameters:@{ @"action" : @"login",
                                 @"username" : username,
                                 @"password" : password,
                                 @"next": @"/member.php?action=getinfo&json=1" }
                      success:^(AFHTTPRequestOperation *operation, NSDictionary *json) {
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
                          if ([username respondsToSelector:@selector(stringValue)]) {
                              username = [(id)username stringValue];
                          }
                          NSDictionary *userInfo = @{ @"userID": [json[@"userid"] stringValue],
                                                      @"username": username,
                                                      @"canSendPrivateMessages": json[@"receivepm"] };
                          [[NSNotificationCenter defaultCenter] postNotificationName:AwfulUserDidLogInNotification object:nil];
                          if (callback) callback(nil, userInfo);
                      } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                          if (operation.response.statusCode == 401) {
                              NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: @"Invalid username or password",
                                                          NSUnderlyingErrorKey: error };
                              error = [NSError errorWithDomain:AwfulErrorDomain
                                                          code:AwfulErrorCodes.badUsernameOrPassword
                                                      userInfo:userInfo];
                          }
                          if (callback) callback(error, nil);
                      }];
}

NSString * const AwfulUserDidLogInNotification = @"com.awfulapp.Awful.UserDidLogInNotification";

- (NSOperation *)locatePostWithID:(NSString *)postID
                          andThen:(void (^)(NSError *error, NSString *threadID, AwfulThreadPage page))callback
{
    // The SA Forums will direct a certain URL to the thread with a given post. We'll wait for that
    // redirect, then parse out the info we need.
    NSURLRequest *request = [_HTTPManager.requestSerializer requestWithMethod:@"GET"
                                                                    URLString:@"showthread.php"
                                                                   parameters:@{ @"goto" : @"post",
                                                                                 @"postid" : postID }];
    __block BOOL didSucceed = NO;
    AFHTTPRequestOperation *op = [_HTTPManager HTTPRequestOperationWithRequest:request success:^(id _, id __) {
        // Once we have the redirect we want, we cancel the operation. So if this "success" callback gets called, we've actually failed.
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
    [op setRedirectResponseBlock:^NSURLRequest *(NSURLConnection *connection, NSURLRequest *request, NSURLResponse *response) {
        AFHTTPRequestOperation *op = weakOp;
        didSucceed = YES;
        if (!response) return request;
        [op cancel];
        if (!callback) return nil;
        NSDictionary *query = [request.URL queryDictionary];
        if ([query[@"threadid"] length] > 0 && [query[@"pagenumber"] integerValue] != 0) {
            dispatch_async(op.completionQueue ?: dispatch_get_main_queue(), ^{
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
            dispatch_async(op.completionQueue ?: dispatch_get_main_queue(), ^{
                callback(error, nil, 0);
            });
        }
        return nil;
    }];
    [_HTTPManager.operationQueue addOperation:op];
    return op;
}

- (NSOperation *)profileUserWithID:(NSString *)userID
                           andThen:(void (^)(NSError *error, AwfulUser *user))callback
{
    return [_HTTPManager GET:@"member.php"
                  parameters:@{ @"action": @"getinfo",
                                @"userid": userID }
            parsingWithBlock:^(NSData *data) {
                return [[ProfileParsedInfo alloc] initWithHTMLData:data];
            } success:^(AFHTTPRequestOperation *operation, ProfileParsedInfo *parsedInfo) {
                AwfulUser *user = [AwfulUser userCreatedOrUpdatedFromProfileInfo:parsedInfo
                                                          inManagedObjectContext:self.managedObjectContext];
                if (user.profilePictureURL && !user.profilePictureURL.host) {
                    NSURL *resolvedURL = [NSURL URLWithString:user.profilePictureURL.absoluteString
                                                relativeToURL:_HTTPManager.baseURL];
                    user.profilePictureURL = resolvedURL.absoluteURL;
                }
                if (callback) callback(nil, user);
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                if (callback) callback(error, nil);
            }];
}

- (NSOperation *)listBansOnPage:(NSInteger)page
                        forUser:(NSString *)userID
                        andThen:(void (^)(NSError *error, NSArray *bans))callback
{
    NSMutableDictionary *parameters = [@{ @"pagenumber": @(page) } mutableCopy];
    if (userID) {
        parameters[@"pagenumber"] = @(page);
    }
    return [_HTTPManager GET:@"banlist.php"
                  parameters:parameters
            parsingWithBlock:^(NSData *data) {
                return [BanParsedInfo bansWithHTMLData:data];
            } success:^(AFHTTPRequestOperation *operation, NSArray *bans) {
                if (callback) callback(nil, bans);
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                if (callback) callback(error, nil);
            }];
}

- (NSOperation *)listPrivateMessagesAndThen:(void (^)(NSError *error, NSArray *messages))callback
{
    return [_HTTPManager GET:@"private.php"
                  parameters:nil
            parsingWithBlock:^(NSData *data) {
                return [[PrivateMessageFolderParsedInfo alloc] initWithHTMLData:data];
            } success:^(AFHTTPRequestOperation *operation, PrivateMessageFolderParsedInfo *parsedInfo) {
                NSArray *messages = [AwfulPrivateMessage privateMessagesWithFolderParsedInfo:parsedInfo
                                                                      inManagedObjectContext:self.managedObjectContext];
                [AwfulPrivateMessage deleteAllInManagedObjectContext:self.managedObjectContext
                                             matchingPredicateFormat:@"NOT(self IN %@)", messages];
                if (callback) callback(nil, messages);
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                if (callback) callback(error, nil);
            }];
}

- (NSOperation *)deletePrivateMessageWithID:(NSString *)messageID
                                    andThen:(void (^)(NSError *error))callback
{
    return [_HTTPManager POST:@"private.php"
                   parameters:@{ @"action": @"dodelete",
                                 @"privatemessageid": messageID,
                                 @"delete": @"yes" }
                      success:^(AFHTTPRequestOperation *operation, id responseObject) {
                          if (callback) callback(nil);
                      } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                          if (callback) callback(error);
                      }];
}

- (NSOperation *)readPrivateMessageWithID:(NSString *)messageID
                                  andThen:(void (^)(NSError *error, AwfulPrivateMessage *message))callback
{
    return [_HTTPManager GET:@"private.php"
                  parameters:@{ @"action": @"show",
                                @"privatemessageid": messageID }
            parsingWithBlock:^(NSData *data) {
                return [[PrivateMessageParsedInfo alloc] initWithHTMLData:data];
            } success:^(AFHTTPRequestOperation *operation, PrivateMessageParsedInfo *parsedInfo) {
                AwfulPrivateMessage *message = [AwfulPrivateMessage privateMessageWithParsedInfo:parsedInfo
                                                                          inManagedObjectContext:self.managedObjectContext];
                if (callback) callback(nil, message);
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                if (callback) callback(error, nil);
            }];
}

- (NSOperation *)quotePrivateMessageWithID:(NSString *)messageID
                                   andThen:(void (^)(NSError *error, NSString *bbcode))callback
{
    return [_HTTPManager GET:@"private.php"
                  parameters:@{ @"action": @"newmessage",
                                @"privatemessageid": messageID }
            parsingWithBlock:^(NSData *data) {
                return [[ComposePrivateMessageParsedInfo alloc] initWithHTMLData:data];
            } success:^(AFHTTPRequestOperation *operation, ComposePrivateMessageParsedInfo *parsedInfo) {
                if (callback) callback(nil, parsedInfo.text);
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                if (callback) callback(error, nil);
            }];
}

- (NSOperation *)listAvailablePrivateMessagePostIconsAndThen:(void (^)(NSError *error,
                                                                       NSArray *postIcons))callback
{
    return [_HTTPManager GET:@"private.php"
                  parameters:@{ @"action": @"newmessage" }
            parsingWithBlock:^(NSData *data) {
                return [[ComposePrivateMessageParsedInfo alloc] initWithHTMLData:data];
            } success:^(AFHTTPRequestOperation *operation, ComposePrivateMessageParsedInfo *parsedInfo) {
                if (callback) callback(nil, CollectPostIcons(parsedInfo.postIconIDs, parsedInfo.postIcons));
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                if (callback) callback(error, nil);
            }];
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
{    NSMutableDictionary *parameters = [@{ @"touser": username,
                                           @"title": subject,
                                           @"iconid": iconID ?: @"0",
                                           @"message": text,
                                           @"action": @"dosend",
                                           @"forward": forwardMessageID ? @"true" : @"",
                                           @"savecopy": @"yes",
                                           @"submit": @"Send Message" } mutableCopy];
    if (replyMessageID || forwardMessageID) {
        parameters[@"prevmessageid"] = replyMessageID ?: forwardMessageID;
    }
    return [_HTTPManager POST:@"private.php"
                   parameters:parameters
                      success:^(AFHTTPRequestOperation *operation, id responseObject) {
                          if (callback) callback(nil);
                      } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                          if (callback) callback(error);
                      }];
}

- (NSOperation *)listAvailablePostIconsForForumWithID:(NSString *)forumID
                                              andThen:(void (^)(NSError *error, NSArray *postIcons, NSArray *secondaryPostIcons, NSString *secondaryIconKey))callback
{
    return [_HTTPManager GET:@"newthread.php"
                  parameters:@{ @"action": @"newthread",
                                @"forumid": forumID }
            parsingWithBlock:^(NSData *data) {
                return [[ComposePrivateMessageParsedInfo alloc] initWithHTMLData:data];
            } success:^(AFHTTPRequestOperation *operation, ComposePrivateMessageParsedInfo *parsedInfo) {
                if (callback) {
                    callback(nil,
                             CollectPostIcons(parsedInfo.postIconIDs, parsedInfo.postIcons),
                             CollectPostIcons(parsedInfo.secondaryIconIDs, parsedInfo.secondaryIcons),
                             parsedInfo.secondaryIconKey);
                }
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                if (callback) callback(error, nil, nil, nil);
            }];
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
    
    return [_HTTPManager GET:@"newthread.php"
                  parameters:@{ @"action": @"newthread",
                                @"forumid": forumID }
            parsingWithBlock:^(NSData *data) {
                return [[NewThreadFormParsedInfo alloc] initWithHTMLData:data];
            } success:^(AFHTTPRequestOperation *operation, NewThreadFormParsedInfo *formInfo) {
                NSMutableDictionary *parameters = [@{ @"forumid": forumID,
                                                      @"action": @"postthread",
                                                      @"formkey": formInfo.formkey,
                                                      @"form_cookie": formInfo.formCookie,
                                                      // I'm not sure if the subject needs any particular escapes, or what's allowed. This is a total guess.
                                                      @"subject": PreparePostText(subject),
                                                      @"iconid": iconID ?: @"0",
                                                      @"message": PreparePostText(text),
                                                      @"polloptions": @"4",
                                                      @"submit": @"Submit New Thread" } mutableCopy];
                if ([secondaryIconID length] > 0 && [secondaryIconKey length] > 0) {
                    parameters[secondaryIconKey] = secondaryIconID;
                }
                if (formInfo.automaticallyParseURLs) {
                    parameters[@"parseurl"] = formInfo.automaticallyParseURLs;
                }
                if (formInfo.bookmarkThread) {
                    parameters[@"bookmark"] = formInfo.bookmarkThread;
                }
                [_HTTPManager POST:@"newthread.php"
                        parameters:parameters
                  parsingWithBlock:^(NSData *data) {
                      return [[SuccessfulNewThreadParsedInfo alloc] initWithHTMLData:data];
                  } success:^(AFHTTPRequestOperation *operation, SuccessfulNewThreadParsedInfo *parsedInfo) {
                      if (callback) callback(nil, parsedInfo.threadID);
                  } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                      if (callback) callback(error, nil);
                  }];
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                if (callback) callback(error, nil);
            }];
}

@end

@implementation AwfulHTTPRequestOperationManager

#pragma mark - ParsedInfo-based parsing

- (AFHTTPRequestOperation *)GET:(NSString *)URLString
                     parameters:(NSDictionary *)parameters
               parsingWithBlock:(id (^)(NSData *data))parseBlock
                        success:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success
                        failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure
{
    NSURL *URL = [NSURL URLWithString:URLString relativeToURL:self.baseURL];
    NSURLRequest *request = [self.requestSerializer requestWithMethod:@"GET" URLString:URL.absoluteString parameters:parameters];
    AFHTTPRequestOperation *operation = [self HTTPRequestOperationWithRequest:request success:success failure:failure];
    AwfulParsedInfoResponseSerializer *responseSerializer = [AwfulParsedInfoResponseSerializer new];
    responseSerializer.parseBlock = parseBlock;
    operation.responseSerializer = responseSerializer;
    [self.operationQueue addOperation:operation];
    return operation;
}

- (AFHTTPRequestOperation *)POST:(NSString *)URLString
                      parameters:(NSDictionary *)parameters
                parsingWithBlock:(id (^)(NSData *data))parseBlock
                         success:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success
                         failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure
{
    NSURL *URL = [NSURL URLWithString:URLString relativeToURL:self.baseURL];
    NSURLRequest *request = [self.requestSerializer requestWithMethod:@"POST" URLString:URL.absoluteString parameters:parameters];
    AFHTTPRequestOperation *operation = [self HTTPRequestOperationWithRequest:request success:success failure:failure];
    AwfulParsedInfoResponseSerializer *responseSerializer = [AwfulParsedInfoResponseSerializer new];
    responseSerializer.parseBlock = parseBlock;
    operation.responseSerializer = responseSerializer;
    [self.operationQueue addOperation:operation];
    return operation;
}

#pragma mark - HTMLReader-based parsing

- (AFHTTPRequestOperation *)HTMLGET:(NSString *)URLString
                         parameters:(NSDictionary *)parameters
                            success:(void (^)(AFHTTPRequestOperation *, id))success
                            failure:(void (^)(AFHTTPRequestOperation *, NSError *))failure
{
    NSURL *URL = [NSURL URLWithString:URLString relativeToURL:self.baseURL];
    NSURLRequest *request = [self.requestSerializer requestWithMethod:@"GET" URLString:URL.absoluteString parameters:parameters];
    AFHTTPRequestOperation *operation = [self HTTPRequestOperationWithRequest:request success:success failure:failure];
    operation.responseSerializer = [AwfulHTMLResponseSerializer new];
    [self.operationQueue addOperation:operation];
    return operation;
}

#pragma mark -

- (AFHTTPRequestOperation *)HTTPRequestOperationWithRequest:(NSURLRequest *)urlRequest
                                                    success:(void (^)(AFHTTPRequestOperation *, id))success
                                                    failure:(void (^)(AFHTTPRequestOperation *, NSError *))failure
{
    // NSURLConnection will, absent relevant HTTP headers, cache responses for an unknown and unfortunately long time.
    // http://blackpixel.com/blog/2012/05/caching-and-nsurlconnection.html
    // This came up when using Awful from some public wi-fi that redirected to a login page. Six hours and a different network later, the same login page was being served up from the cache.
    AFHTTPRequestOperation *op = [super HTTPRequestOperationWithRequest:urlRequest
                                                                success:success
                                                                failure:failure];
    if ([[urlRequest HTTPMethod] compare:@"GET" options:NSCaseInsensitiveSearch] == NSOrderedSame) {
        [op setCacheResponseBlock:^(NSURLConnection *connection, NSCachedURLResponse *cachedResponse) {
            if ([connection currentRequest].cachePolicy == NSURLRequestUseProtocolCachePolicy) {
                NSHTTPURLResponse *response = (id)[cachedResponse response];
                NSDictionary *headers = [response allHeaderFields];
                if (!(headers[@"Cache-Control"] || headers[@"Expires"])) {
                    NSLog(@"refusing to cache response to %@", urlRequest.URL);
                    return (NSCachedURLResponse *)nil;
                }
            }
            return cachedResponse;
        }];
    }
    return op;
}

@end
