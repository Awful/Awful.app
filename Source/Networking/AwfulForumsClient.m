//  AwfulForumsClient.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulForumsClient.h"
#import "AwfulAppDelegate.h"
#import "AwfulErrorDomain.h"
#import "AwfulFormScraper.h"
#import "AwfulForumHierarchyScraper.h"
#import "AwfulHTTPRequestOperationManager.h"
#import "AwfulLepersColonyPageScraper.h"
#import "AwfulMessageFolderScraper.h"
#import "AwfulModels.h"
#import "AwfulPostsPageScraper.h"
#import "AwfulPrivateMessageScraper.h"
#import "AwfulProfileScraper.h"
#import "AwfulScanner.h"
#import "AwfulSettings.h"
#import "AwfulThreadListScraper.h"
#import "AwfulThreadTag.h"
#import "AwfulUIKitAndFoundationCategories.h"
#import "HTMLNode+CachedSelector.h"
#import "NSManagedObjectContext+AwfulConvenience.h"
#import <Crashlytics/Crashlytics.h>

@implementation AwfulForumsClient
{
    AwfulHTTPRequestOperationManager *_HTTPManager;
    NSManagedObjectContext *_backgroundManagedObjectContext;
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
    
    // When a user changes their password, subsequent HTTP operations will come back without a login cookie. So any operation might bear the news that we've been logged out.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(networkingOperationDidStart:)
                                                 name:AFNetworkingOperationDidStartNotification
                                               object:nil];
    return self;
}

+ (AwfulForumsClient *)client
{
    static AwfulForumsClient *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [AwfulForumsClient new];
    });
    return instance;
}

- (void)setManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext) {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:NSManagedObjectContextDidSaveNotification
                                                      object:_managedObjectContext];
    }
    
    _managedObjectContext = managedObjectContext;
    _backgroundManagedObjectContext = nil;
    
    if (managedObjectContext) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(mainManagedObjectContextDidSave:)
                                                     name:NSManagedObjectContextDidSaveNotification
                                                   object:managedObjectContext];
        
        _backgroundManagedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        _backgroundManagedObjectContext.persistentStoreCoordinator = managedObjectContext.persistentStoreCoordinator;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(backgroundManagedObjectContextDidSave:)
                                                     name:NSManagedObjectContextDidSaveNotification
                                                   object:_backgroundManagedObjectContext];
    }
}

- (void)mainManagedObjectContextDidSave:(NSNotification *)note
{
    NSManagedObjectContext *context = _backgroundManagedObjectContext;
    [context performBlock:^{
        [context mergeChangesFromContextDidSaveNotification:note];
    }];
}

- (void)backgroundManagedObjectContextDidSave:(NSNotification *)note
{
    NSManagedObjectContext *context = self.managedObjectContext;
    [context performBlock:^{
        [context mergeChangesFromContextDidSaveNotification:note];
    }];
}

- (void)reset
{
    [_HTTPManager.operationQueue cancelAllOperations];
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
}

- (void)settingsDidChange:(NSNotification *)note
{
    if ([note.userInfo[AwfulSettingsDidChangeSettingKey] isEqual:AwfulSettingsKeys.customBaseURL]) {
        [self reset];
    }
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

- (NSDate*)loginCookieExpiryDate
{
    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:_HTTPManager.baseURL];
    for (NSHTTPCookie *cookie in cookies) {
        if ([cookie.name isEqualToString:@"bbuserid"]) {
            return cookie.expiresDate;
        }
    }
    return nil;
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
                      withThreadTag:(AwfulThreadTag *)threadTag
                             onPage:(NSInteger)page
                            andThen:(void (^)(NSError *error, NSArray *threads))callback
{
    NSMutableDictionary *parameters = [@{ @"forumid": forum.forumID,
                                          @"perpage": @40,
                                          @"pagenumber": @(page) } mutableCopy];
    if (threadTag.threadTagID.length > 0) {
        parameters[@"posticon"] = threadTag.threadTagID;
    }
    NSManagedObjectContext *managedObjectContext = _backgroundManagedObjectContext;
    NSManagedObjectContext *mainManagedObjectContext = self.managedObjectContext;
    return [_HTTPManager GET:@"forumdisplay.php" parameters:parameters success:^(AFHTTPRequestOperation *operation, HTMLDocument *document) {
        [managedObjectContext performBlock:^{
            AwfulThreadListScraper *scraper = [AwfulThreadListScraper new];
            NSError *error;
            NSArray *threads = [scraper scrapeDocument:document
                                               fromURL:operation.response.URL
                              intoManagedObjectContext:managedObjectContext
                                                 error:&error];
            if (callback) {
                NSArray *objectIDs = [threads valueForKey:@"objectID"];
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    NSArray *threads = [mainManagedObjectContext awful_objectsWithIDs:objectIDs];
                    callback(error, threads);
                }];
            }
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil);
    }];
}

- (NSOperation *)listBookmarkedThreadsOnPage:(NSInteger)page
                                     andThen:(void (^)(NSError *error, NSArray *threads))callback
{
    NSManagedObjectContext *managedObjectContext = _backgroundManagedObjectContext;
    NSManagedObjectContext *mainManagedObjectContext = self.managedObjectContext;
    return [_HTTPManager GET:@"bookmarkthreads.php"
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
                NSArray *objectIDs = [threads valueForKey:@"objectID"];
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    NSArray *threads = [mainManagedObjectContext awful_objectsWithIDs:objectIDs];
                    callback(error, threads);
                }];
            }
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil);
    }];
}

- (NSOperation *)listPostsInThread:(AwfulThread *)thread
                         writtenBy:(AwfulUser *)author
                            onPage:(AwfulThreadPage)page
                           andThen:(void (^)(NSError *error, NSArray *posts, NSUInteger firstUnreadPost, NSString *advertisementHTML))callback
{
    NSMutableDictionary *parameters = [@{ @"threadid": thread.threadID,
                                          @"perpage": @40 } mutableCopy];
    if (page == AwfulThreadPageNextUnread) {
        parameters[@"goto"] = @"newpost";
    } else if (page == AwfulThreadPageLast) {
        parameters[@"goto"] = @"lastpost";
    } else {
        parameters[@"pagenumber"] = @(page);
    }
    if (author.userID) {
        parameters[@"userid"] = author.userID;
    }
    NSManagedObjectContext *managedObjectContext = _backgroundManagedObjectContext;
    NSManagedObjectContext *mainManagedObjectContext = self.managedObjectContext;
    NSURL *URL = [NSURL URLWithString:@"showthread.php" relativeToURL:_HTTPManager.baseURL];
    NSError *error;
    NSURLRequest *request = [_HTTPManager.requestSerializer requestWithMethod:@"GET" URLString:URL.absoluteString parameters:parameters error:&error];
    if (!request) {
        if (callback) {
            callback(error, nil, 0, nil);
            return nil;
        }
    }
    AFHTTPRequestOperation *operation = [_HTTPManager HTTPRequestOperationWithRequest:request
                                                                              success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        [managedObjectContext performBlock:^{
            AwfulPostsPageScraper *scraper = [AwfulPostsPageScraper new];
            NSError *error;
            NSArray *posts = [scraper scrapeDocument:document
                                             fromURL:operation.response.URL
                            intoManagedObjectContext:managedObjectContext
                                               error:&error];
            if (callback) {
                NSInteger firstUnreadPostIndex = NSNotFound;
                if (page == AwfulThreadPageNextUnread) {
                    AwfulScanner *scanner = [AwfulScanner scannerWithString:operation.response.URL.fragment];
                    if ([scanner scanString:@"pti" intoString:nil]) {
                        [scanner scanInteger:&firstUnreadPostIndex];
                        if (firstUnreadPostIndex == 0) {
                            firstUnreadPostIndex = NSNotFound;
                        } else {
                            firstUnreadPostIndex--;
                        }
                    }
                }
                
                NSArray *objectIDs = [posts valueForKey:@"objectID"];
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    NSArray *posts = [mainManagedObjectContext awful_objectsWithIDs:objectIDs];
                    callback(nil, posts, firstUnreadPostIndex, nil);
                }];
            }
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil, NSNotFound, nil);
    }];
    
    // SA: We set perpage=40 above to effectively ignore the user's "number of posts per page" setting on the Forums proper. When we get redirected (i.e. goto=newpost or goto=lastpost), the page we're redirected to is appropriate for our hardcoded perpage=40. However, the redirected URL has **no** perpage parameter, so it defaults to the user's setting from the Forums proper. This block maintains our hardcoded perpage value.
    [operation setRedirectResponseBlock:^(NSURLConnection *connection, NSURLRequest *request, NSURLResponse *redirectResponse) {
        NSURL *URL = request.URL;
        NSMutableDictionary *queryDictionary = [URL.queryDictionary mutableCopy];
        queryDictionary[@"perpage"] = @"40";
        NSMutableArray *queryParts = [NSMutableArray new];
        for (id key in queryDictionary) {
            [queryParts addObject:[NSString stringWithFormat:@"%@=%@", key, queryDictionary[key]]];
        }
        NSURLComponents *components = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:YES];
        components.percentEncodedQuery = [queryParts componentsJoinedByString:@"&"];
        NSMutableURLRequest *updatedRequest = [request mutableCopy];
        updatedRequest.URL = components.URL;
        return updatedRequest;
    }];
    [operation start];
    return operation;
}

- (NSOperation *)learnLoggedInUserInfoAndThen:(void (^)(NSError *error, AwfulUser *user))callback
{
    NSManagedObjectContext *managedObjectContext = _backgroundManagedObjectContext;
    NSManagedObjectContext *mainManagedObjectContext = self.managedObjectContext;
    return [_HTTPManager GET:@"member.php"
                  parameters:@{ @"action": @"getinfo" }
                     success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        [managedObjectContext performBlock:^{
            AwfulProfileScraper *scraper = [AwfulProfileScraper new];
            NSError *error;
            AwfulUser *user = [scraper scrapeDocument:document
                                              fromURL:operation.response.URL
                             intoManagedObjectContext:managedObjectContext
                                                error:&error];
            if (callback) {
                NSManagedObjectID *objectID = user.objectID;
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    AwfulUser *user = [mainManagedObjectContext awful_objectWithID:objectID];
                    callback(error, user);
                }];
            }
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil);
    }];
}

- (NSOperation *)setThread:(AwfulThread *)thread
              isBookmarked:(BOOL)isBookmarked
                   andThen:(void (^)(NSError *error))callback
{
    return [_HTTPManager POST:@"bookmarkthreads.php"
                   parameters:@{ @"json": @"1",
                                 @"action": isBookmarked ? @"add" : @"remove",
                                 @"threadid": thread.threadID }
                      success:^(AFHTTPRequestOperation *operation, id responseObject)
    {
        thread.bookmarked = isBookmarked;
        if (callback) callback(nil);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error);
    }];
}

- (NSOperation *)taxonomizeForumsAndThen:(void (^)(NSError *error, NSArray *categories))callback
{
    // Seems like only forumdisplay.php and showthread.php have the <select> with a complete list of forums. We'll use the Main "forum" as it's the smallest page with the drop-down list.
    NSManagedObjectContext *managedObjectContext = _backgroundManagedObjectContext;
    NSManagedObjectContext *mainManagedObjectContext = self.managedObjectContext;
    return [_HTTPManager GET:@"forumdisplay.php"
                  parameters:@{ @"forumid": @"48" }
                     success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        [managedObjectContext performBlock:^{
            AwfulForumHierarchyScraper *scraper = [AwfulForumHierarchyScraper new];
            NSError *error;
            NSArray *categories = [scraper scrapeDocument:document
                                                  fromURL:operation.response.URL
                                 intoManagedObjectContext:managedObjectContext
                                                    error:&error];
            if (callback) {
                NSArray *objectIDs = [categories valueForKey:@"objectID"];
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    NSArray *categories = [mainManagedObjectContext awful_objectsWithIDs:objectIDs];
                    callback(error, categories);
                }];
            }
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil);
    }];
}

- (NSOperation *)replyToThread:(AwfulThread *)thread
                    withBBcode:(NSString *)text
                       andThen:(void (^)(NSError *error, AwfulPost *post))callback
{
    NSManagedObjectContext *managedObjectContext = _backgroundManagedObjectContext;
    NSManagedObjectContext *mainManagedObjectContext = self.managedObjectContext;
    return [_HTTPManager GET:@"newreply.php"
                  parameters:@{ @"action" : @"newreply",
                                @"threadid" : thread.threadID }
                     success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        [managedObjectContext performBlock:^{
            AwfulFormScraper *scraper = [AwfulFormScraper new];
            NSError *error;
            NSArray *forms = [scraper scrapeDocument:document
                                             fromURL:operation.response.URL
                            intoManagedObjectContext:managedObjectContext
                                               error:&error];
            NSMutableDictionary *parameters;
            for (AwfulForm *form in forms) {
                NSMutableDictionary *possibleParameters = [form recommendedParameters];
                if (possibleParameters[@"threadid"]) {
                    parameters = possibleParameters;
                    break;
                }
            }
            if (!parameters) {
                if (callback) {
                    NSString *description;
                    if (thread.closed) {
                        description = @"Could not reply; the thread may be closed.";
                    } else {
                        description = @"Could not reply; failed to find the form.";
                    }
                    error = [NSError errorWithDomain:AwfulErrorDomain
                                                code:AwfulErrorCodes.parseError
                                            userInfo:@{ NSLocalizedDescriptionKey: description }];
                    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                        callback(error, nil);
                    }];
                }
                return;
            }
            parameters[@"message"] = text;
            [_HTTPManager POST:@"newreply.php"
                    parameters:parameters
                       success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
            {
                AwfulPost *post;
                HTMLElement *link = ([document awful_firstNodeMatchingCachedSelector:@"a[href *= 'goto=post']"] ?:
                                         [document awful_firstNodeMatchingCachedSelector:@"a[href *= 'goto=lastpost']"]);
                NSURL *URL = [NSURL URLWithString:link[@"href"]];
                if ([URL.queryDictionary[@"goto"] isEqual:@"post"]) {
                    NSString *postID = URL.queryDictionary[@"postid"];
                    if (postID.length > 0) {
                        post = [AwfulPost firstOrNewPostWithPostID:postID inManagedObjectContext:mainManagedObjectContext];
                    }
                }
                if (callback) callback(nil, post);
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                if (callback) callback(error, nil);
            }];
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil);
    }];
}

- (NSOperation *)findBBcodeContentsWithPost:(AwfulPost *)post
                                    andThen:(void (^)(NSError *error, NSString *text))callback
{
    NSManagedObjectContext *managedObjectContext = _backgroundManagedObjectContext;
    return [_HTTPManager GET:@"editpost.php"
                  parameters:@{ @"action": @"editpost",
                                @"postid": post.postID }
                     success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        [managedObjectContext performBlock:^{
            AwfulFormScraper *scraper = [AwfulFormScraper new];
            NSError *error;
            NSArray *forms = [scraper scrapeDocument:document
                                             fromURL:operation.response.URL
                            intoManagedObjectContext:managedObjectContext
                                               error:&error];
            for (AwfulForm *form in forms) {
                for (AwfulFormItem *text in form.texts) {
                    if ([text.name isEqualToString:@"message"]) {
                        if (callback) {
                            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                                callback(error, text.value);
                            }];
                        }
                        return;
                    }
                }
            }
            
            if (callback) {
                error = [NSError errorWithDomain:AwfulErrorDomain
                                            code:AwfulErrorCodes.parseError
                                        userInfo:@{ NSLocalizedDescriptionKey: @"Failed getting post text; could not find form" }];
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    callback(error, nil);
                }];
            }
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil);
    }];
}

- (NSOperation *)quoteBBcodeContentsWithPost:(AwfulPost *)post
                                     andThen:(void (^)(NSError *error, NSString *quotedText))callback
{
    return [_HTTPManager GET:@"newreply.php"
                  parameters:@{ @"action": @"newreply",
                                @"postid": post.postID,
                                @"json": @1 }
                     success:^(AFHTTPRequestOperation *operation, NSDictionary *json)
    {
        if (!callback) return;
        // If you quote a post from a thread that's been moved to the Gas Chamber, you don't get a post body. That's an error, even though the HTTP operation succeeded.
        if ([json isKindOfClass:[NSDictionary class]] && json[@"body"]) {
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

- (NSOperation *)editPost:(AwfulPost *)post
                setBBcode:(NSString *)text
                  andThen:(void (^)(NSError *error))callback
{
    NSManagedObjectContext *managedObjectContext = _backgroundManagedObjectContext;
    return [_HTTPManager GET:@"editpost.php"
                  parameters:@{ @"action": @"editpost",
                                @"postid": post.postID }
                     success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        [managedObjectContext performBlock:^{
            AwfulFormScraper *scraper = [AwfulFormScraper new];
            NSError *error;
            NSArray *forms = [scraper scrapeDocument:document
                                             fromURL:operation.response.URL
                            intoManagedObjectContext:managedObjectContext
                                               error:&error];
            NSMutableDictionary *parameters;
            for (AwfulForm *form in forms) {
                NSMutableDictionary *possibleParameters = [form recommendedParameters];
                if (possibleParameters[@"postid"]) {
                    parameters = possibleParameters;
                    break;
                }
            }
            if (!parameters) {
                if (callback) {
                    error = [NSError errorWithDomain:AwfulErrorDomain
                                                code:AwfulErrorCodes.parseError
                                            userInfo:@{ NSLocalizedDescriptionKey: @"Failed to edit post; could not find form" }];
                    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                        callback(error);
                    }];
                }
                return;
            }
            parameters[@"message"] = text;
            [_HTTPManager POST:@"editpost.php"
                    parameters:parameters
                       success:^(AFHTTPRequestOperation *operation, id responseObject)
            {
                if (callback) callback(nil);
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                if (callback) callback(error);
            }];
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error);
    }];
}

- (NSOperation *)rateThread:(AwfulThread *)thread
                           :(NSInteger)rating
                    andThen:(void (^)(NSError *error))callback
{
    return [_HTTPManager POST:@"threadrate.php"
                   parameters:@{ @"vote": @(MAX(5, MIN(1, rating))),
                                 @"threadid": thread.threadID }
                      success:^(AFHTTPRequestOperation *operation, id responseObject) {
                          if (callback) callback(nil);
                      } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                          if (callback) callback(error);
                      }];
}

- (NSOperation *)markThreadReadUpToPost:(AwfulPost *)post
                                andThen:(void (^)(NSError *error))callback
{
    return [_HTTPManager GET:@"showthread.php"
                  parameters:@{ @"action": @"setseen",
                                @"threadid": post.thread.threadID,
                                @"index": @(post.threadIndex) }
                     success:^(AFHTTPRequestOperation *operation, id responseObject)
    {
        if (callback) callback(nil);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error);
    }];
}

- (NSOperation *)markThreadUnread:(AwfulThread *)thread
                          andThen:(void (^)(NSError *error))callback
{
    return [_HTTPManager POST:@"showthread.php"
                   parameters:@{ @"threadid": thread.threadID,
                                 @"action": @"resetseen",
                                 @"json": @"1" }
                      success:^(AFHTTPRequestOperation *operation, id responseObject)
    {
        if (callback) callback(nil);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error);
    }];
}

- (NSOperation *)logInWithUsername:(NSString *)username
                          password:(NSString *)password
                           andThen:(void (^)(NSError *error, AwfulUser *user))callback
{
    NSManagedObjectContext *managedObjectContext = _backgroundManagedObjectContext;
    NSManagedObjectContext *mainManagedObjectContext = self.managedObjectContext;
    return [_HTTPManager POST:@"account.php?json=1"
                   parameters:@{ @"action" : @"login",
                                 @"username" : username,
                                 @"password" : password,
                                 @"next": @"/member.php?action=getinfo" }
                      success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        [managedObjectContext performBlock:^{
            AwfulProfileScraper *scraper = [AwfulProfileScraper new];
            NSError *error;
            AwfulUser *user = [scraper scrapeDocument:document
                                              fromURL:operation.response.URL
                             intoManagedObjectContext:self.managedObjectContext
                                                error:&error];
            if (callback) {
                NSManagedObjectID *objectID = user.objectID;
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    AwfulUser *user = [mainManagedObjectContext awful_objectWithID:objectID];
                    callback(error, user);
                }];
            }
        }];
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

- (NSOperation *)locatePostWithID:(NSString *)postID
                          andThen:(void (^)(NSError *error, AwfulPost *post, AwfulThreadPage page))callback
{
    // The SA Forums will direct a certain URL to the thread with a given post. We'll wait for that
    // redirect, then parse out the info we need.
    NSURL *URL = [NSURL URLWithString:@"showthread.php" relativeToURL:_HTTPManager.baseURL];
    NSURLRequest *request = [_HTTPManager.requestSerializer requestWithMethod:@"GET"
                                                                    URLString:URL.absoluteString
                                                                   parameters:@{ @"goto" : @"post",
                                                                                 @"postid" : postID }
																		error:nil];
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
    NSManagedObjectContext *managedObjectContext = _backgroundManagedObjectContext;
    NSManagedObjectContext *mainManagedObjectContext = self.managedObjectContext;
    __weak AFHTTPRequestOperation *weakOp = op;
    [op setRedirectResponseBlock:^NSURLRequest *(NSURLConnection *connection, NSURLRequest *request, NSURLResponse *response) {
        AFHTTPRequestOperation *op = weakOp;
        didSucceed = YES;
        if (!response) return request;
        [op cancel];
        NSDictionary *query = [request.URL queryDictionary];
        if ([query[@"threadid"] length] > 0 && [query[@"pagenumber"] integerValue] != 0) {
            [managedObjectContext performBlock:^{
                AwfulPost *post = [AwfulPost firstOrNewPostWithPostID:postID inManagedObjectContext:managedObjectContext];
                post.thread = [AwfulThread firstOrNewThreadWithThreadID:query[@"threadid"] inManagedObjectContext:managedObjectContext];
                NSError *error;
                BOOL ok = [managedObjectContext save:&error];
                if (callback) {
                    NSManagedObjectID *objectID = post.objectID;
                    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                        if (ok) {
                            AwfulPost *post = [mainManagedObjectContext awful_objectWithID:objectID];
                            callback(nil, post, [query[@"pagenumber"] integerValue]);
                        } else {
                            NSString *message = @"The post's thread could not be parsed";
                            NSError *underlyingError = error;
                            NSError *error = [NSError errorWithDomain:AwfulErrorDomain
                                                                 code:AwfulErrorCodes.parseError
                                                             userInfo:@{ NSLocalizedDescriptionKey: message,
                                                                         NSUnderlyingErrorKey: underlyingError }];
                            callback(error, nil, 0);
                        }
                    }];
                }
            }];
        } else {
            if (callback) {
                NSString *missingInfo = query[@"threadid"] ? @"page number" : @"thread ID";
                NSString *message = [NSString stringWithFormat:@"The %@ could not be found",
                                     missingInfo];
                NSError *error = [NSError errorWithDomain:AwfulErrorDomain
                                                     code:AwfulErrorCodes.parseError
                                                 userInfo:@{ NSLocalizedDescriptionKey: message }];
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    callback(error, nil, 0);
                }];
            }
        }
        return nil;
    }];
    [_HTTPManager.operationQueue addOperation:op];
    return op;
}

- (NSOperation *)profileUserWithID:(NSString *)userID
                           andThen:(void (^)(NSError *error, AwfulUser *user))callback
{
    NSManagedObjectContext *managedObjectContext = _backgroundManagedObjectContext;
    NSManagedObjectContext *mainManagedObjectContext = self.managedObjectContext;
    return [_HTTPManager GET:@"member.php"
                  parameters:@{ @"action": @"getinfo",
                                @"userid": userID }
                     success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        [managedObjectContext performBlock:^{
            AwfulProfileScraper *scraper = [AwfulProfileScraper new];
            NSError *error;
            AwfulUser *user = [scraper scrapeDocument:document
                                              fromURL:operation.response.URL
                             intoManagedObjectContext:managedObjectContext
                                                error:&error];
            if (callback) {
                NSManagedObjectID *objectID = user.objectID;
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    AwfulUser *user = [mainManagedObjectContext awful_objectWithID:objectID];
                    callback(error, user);
                }];
            }
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil);
    }];
}

- (NSOperation *)listBansOnPage:(NSInteger)page
                        forUser:(AwfulUser *)user
                        andThen:(void (^)(NSError *error, NSArray *bans))callback
{
    NSMutableDictionary *parameters = [@{ @"pagenumber": @(page) } mutableCopy];
    if (user.userID) {
        parameters[@"userid"] = user.userID;
    }
    NSManagedObjectContext *managedObjectContext = _backgroundManagedObjectContext;
    return [_HTTPManager GET:@"banlist.php"
                  parameters:parameters
                     success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        [managedObjectContext performBlock:^{
            AwfulLepersColonyPageScraper *scraper = [AwfulLepersColonyPageScraper new];
            NSError *error;
            NSArray *bans = [scraper scrapeDocument:document
                                            fromURL:operation.response.URL
                           intoManagedObjectContext:managedObjectContext
                                              error:&error];
            if (callback) {
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    callback(error, bans);
                }];
            }
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil);
    }];
}

- (NSOperation *)listPrivateMessageInboxAndThen:(void (^)(NSError *error, NSArray *messages))callback
{
    NSManagedObjectContext *managedObjectContext = _backgroundManagedObjectContext;
    NSManagedObjectContext *mainManagedObjectContext = self.managedObjectContext;
    CLSLog(@"%s fetching list into %@", __PRETTY_FUNCTION__, managedObjectContext);
    return [_HTTPManager GET:@"private.php"
                  parameters:nil
                     success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        CLSLog(@"%s fetch succeeded, ready to insert into %@", __PRETTY_FUNCTION__, managedObjectContext);
        [managedObjectContext performBlock:^{
            CLSLog(@"%s inserting into %@", __PRETTY_FUNCTION__, managedObjectContext);
            AwfulMessageFolderScraper *scraper = [AwfulMessageFolderScraper new];
            NSError *error;
            NSArray *messages = [scraper scrapeDocument:document
                                                fromURL:operation.response.URL
                               intoManagedObjectContext:managedObjectContext
                                                  error:&error];
            if (callback) {
                NSArray *objectIDs = [messages valueForKey:@"objectID"];
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    NSArray *messages = [mainManagedObjectContext awful_objectsWithIDs:objectIDs];
                    callback(error, messages);
                }];
            }
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil);
    }];
}

- (NSOperation *)deletePrivateMessage:(AwfulPrivateMessage *)message
                              andThen:(void (^)(NSError *error))callback
{
    return [_HTTPManager POST:@"private.php"
                   parameters:@{ @"action": @"dodelete",
                                 @"privatemessageid": message.messageID,
                                 @"delete": @"yes" }
                      success:^(AFHTTPRequestOperation *operation, id responseObject)
    {
        if (callback) callback(nil);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error);
    }];
}

- (NSOperation *)readPrivateMessage:(AwfulPrivateMessage *)message
                            andThen:(void (^)(NSError *error))callback
{
    NSManagedObjectContext *managedObjectContext = _backgroundManagedObjectContext;
    return [_HTTPManager GET:@"private.php"
                  parameters:@{ @"action": @"show",
                                @"privatemessageid": message.messageID }
                     success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        [managedObjectContext performBlock:^{
            AwfulPrivateMessageScraper *scraper = [AwfulPrivateMessageScraper new];
            NSError *error;
            [scraper scrapeDocument:document
                            fromURL:operation.response.URL
           intoManagedObjectContext:managedObjectContext
                              error:&error];
            if (callback) {
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    callback(error);
                }];
            }
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error);
    }];
}

- (NSOperation *)quoteBBcodeContentsOfPrivateMessage:(AwfulPrivateMessage *)message
                                             andThen:(void (^)(NSError *error, NSString *BBcode))callback
{
    NSManagedObjectContext *managedObjectContext = _backgroundManagedObjectContext;
    return [_HTTPManager GET:@"private.php"
                  parameters:@{ @"action": @"newmessage",
                                @"privatemessageid": message.messageID }
                     success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        [managedObjectContext performBlock:^{
            AwfulFormScraper *scraper = [AwfulFormScraper new];
            NSError *error;
            NSArray *forms = [scraper scrapeDocument:document
                                             fromURL:operation.response.URL
                            intoManagedObjectContext:managedObjectContext
                                               error:&error];
            for (AwfulForm *form in forms) {
                for (AwfulFormItem *text in form.texts) {
                    if ([text.name isEqualToString:@"message"]) {
                        if (callback) {
                            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                                callback(error, text.value);
                            }];
                        }
                        return;
                    }
                }
            }
            
            if (callback) {
                error = [NSError errorWithDomain:AwfulErrorDomain
                                            code:AwfulErrorCodes.parseError
                                        userInfo:@{ NSLocalizedDescriptionKey: @"Failed quoting private message; could not find text box" }];
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    callback(error, nil);
                }];
            }
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil);
    }];
}

- (NSOperation *)listAvailablePrivateMessageThreadTagsAndThen:(void (^)(NSError *error, NSArray *threadTags))callback
{
    NSManagedObjectContext *managedObjectContext = _backgroundManagedObjectContext;
    NSManagedObjectContext *mainManagedObjectContext = self.managedObjectContext;
    return [_HTTPManager GET:@"private.php"
                  parameters:@{ @"action": @"newmessage" }
                     success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        [managedObjectContext performBlock:^{
            AwfulFormScraper *scraper = [AwfulFormScraper new];
            NSError *error;
            NSArray *forms = [scraper scrapeDocument:document
                                             fromURL:operation.response.URL
                            intoManagedObjectContext:managedObjectContext
                                               error:&error];
            for (AwfulForm *form in forms) {
                NSArray *tags = form.threadTags;
                if (tags.count > 0) {
                    if (callback) {
                        NSArray *objectIDs = [tags valueForKey:@"objectID"];
                        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                            NSArray *tags = [mainManagedObjectContext awful_objectsWithIDs:objectIDs];
                            callback(error, tags);
                        }];
                    }
                    return;
                }
            }
            if (callback) {
                error = [NSError errorWithDomain:AwfulErrorDomain
                                            code:AwfulErrorCodes.parseError
                                        userInfo:@{ NSLocalizedDescriptionKey: @"Failed scraping thread tags from new private message form" }];
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    callback(error, nil);
                }];
            }
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil);
    }];
}

- (NSOperation *)sendPrivateMessageTo:(NSString *)username
                          withSubject:(NSString *)subject
                            threadTag:(AwfulThreadTag *)threadTag
                               BBcode:(NSString *)text
                     asReplyToMessage:(AwfulPrivateMessage *)regardingMessage
                 forwardedFromMessage:(AwfulPrivateMessage *)forwardedMessage
                              andThen:(void (^)(NSError *error))callback
{
    NSMutableDictionary *parameters = [@{ @"touser": username,
                                           @"title": subject,
                                           @"iconid": threadTag.threadTagID ?: @"0",
                                           @"message": text,
                                           @"action": @"dosend",
                                           @"forward": forwardedMessage.messageID ? @"true" : @"",
                                           @"savecopy": @"yes",
                                           @"submit": @"Send Message" } mutableCopy];
    if (regardingMessage || forwardedMessage) {
        parameters[@"prevmessageid"] = regardingMessage.messageID ?: forwardedMessage.messageID;
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
                                              andThen:(void (^)(NSError *error, AwfulForm *form))callback
{
    NSManagedObjectContext *managedObjectContext = _backgroundManagedObjectContext;
    NSManagedObjectContext *mainManagedObjectContext = self.managedObjectContext;
    return [_HTTPManager GET:@"newthread.php"
                  parameters:@{ @"action": @"newthread",
                                @"forumid": forumID }
                     success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        [managedObjectContext performBlock:^{
            AwfulFormScraper *scraper = [AwfulFormScraper new];
            NSError *error;
            NSArray *forms = [scraper scrapeDocument:document
                                             fromURL:operation.response.URL
                            intoManagedObjectContext:managedObjectContext
                                               error:&error];
            for (AwfulForm *form in forms) {
                if (form.threadTags.count > 0) {
                    if (callback) {
                        NSArray *objectIDs = [form.threadTags valueForKey:@"objectID"];
                        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                            form.threadTags = [mainManagedObjectContext awful_objectsWithIDs:objectIDs];
                            callback(error, form);
                        }];
                    }
                    return;
                }
            }
            if (callback) {
                error = [NSError errorWithDomain:AwfulErrorDomain
                                            code:AwfulErrorCodes.parseError
                                        userInfo:@{ NSLocalizedDescriptionKey: @"Failed parsing new thread form" }];
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    callback(error, nil);
                }];
            }
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil);
    }];
}

- (NSOperation *)postThreadInForum:(AwfulForum *)forum
                       withSubject:(NSString *)subject
                         threadTag:(AwfulThreadTag *)threadTag
                      secondaryTag:(AwfulThreadTag *)secondaryTag
               secondaryTagFormKey:(NSString *)secondaryTagFormKey
                            BBcode:(NSString *)text
                           andThen:(void (^)(NSError *error, AwfulThread *thread))callback
{
    NSManagedObjectContext *managedObjectContext = _backgroundManagedObjectContext;
    return [_HTTPManager GET:@"newthread.php"
                  parameters:@{ @"action": @"newthread",
                                @"forumid": forum.forumID }
                     success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        [managedObjectContext performBlock:^{
            AwfulFormScraper *scraper = [AwfulFormScraper new];
            NSError *error;
            NSArray *forms = [scraper scrapeDocument:document
                                             fromURL:operation.response.URL
                            intoManagedObjectContext:managedObjectContext
                                               error:&error];
            AwfulForm *form;
            NSMutableDictionary *parameters;
            for (AwfulForm *possibleForm in forms) {
                NSMutableDictionary *possibleParameters = [possibleForm recommendedParameters];
                if (possibleParameters[@"forumid"]) {
                    form = possibleForm;
                    parameters = possibleParameters;
                    break;
                }
            }
            if (!parameters) {
                error = [NSError errorWithDomain:AwfulErrorDomain
                                            code:AwfulErrorCodes.parseError
                                        userInfo:@{ NSLocalizedDescriptionKey: @"Failed to scrape new thread form" }];
                if (callback) {
                    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                        callback(error, nil);
                    }];
                }
                return;
            }
            parameters[@"subject"] = [subject copy];
            parameters[form.threadTagName] = threadTag.threadTagID ?: @"0";
            parameters[@"message"] = [text copy];
            if (secondaryTag) {
                parameters[form.secondaryThreadTagName] = secondaryTag.threadTagID;
            }
            [parameters removeObjectForKey:@"preview"];
            [_HTTPManager POST:@"newthread.php"
                    parameters:parameters
                       success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
            {
                HTMLElement *link = [document awful_firstNodeMatchingCachedSelector:@"a[href *= 'showthread']"];
                NSURL *URL = [NSURL URLWithString:link[@"href"]];
                NSString *threadID = URL.queryDictionary[@"threadid"];
                AwfulThread *thread = [AwfulThread firstOrNewThreadWithThreadID:threadID inManagedObjectContext:managedObjectContext];
                if (callback) callback(nil, thread);
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                if (callback) callback(error, nil);
            }];
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil);
    }];
}

@end
