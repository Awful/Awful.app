//  AwfulForumsClient.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulForumsClient.h"
#import "AwfulForumHierarchyScraper.h"
#import "AwfulHTTPRequestOperationManager.h"
#import "AwfulPostScraper.h"
#import "AwfulPostsPageScraper.h"
#import "AwfulScanner.h"
#import "AwfulThreadListScraper.h"
#import "AwfulUnreadPrivateMessageCountScraper.h"
#import "LepersColonyPageScraper.h"
#import "NSURLQueryDictionary.h"
#import "PrivateMessageFolderScraper.h"
#import "PrivateMessageScraper.h"
#import "ProfileScraper.h"
#import <AwfulCore/AwfulCore-Swift.h>

@interface NSManagedObjectContext (AwfulConvenient)

/// -objectWithID: except nil-safe and returns `id` for easy casting.
- (id)awful_objectWithID:(NSManagedObjectID *)objectID;

/// -objectWithID: for each item in the array.
- (NSArray *)awful_objectsWithIDs:(NSArray *)objectIDs;

@end

@implementation AwfulForumsClient
{
    AwfulHTTPRequestOperationManager *_HTTPManager;
    NSManagedObjectContext *_backgroundManagedObjectContext;
    LastModifiedContextObserver *_lastModifiedObserver;
}

- (void)dealloc
{
    [_HTTPManager.operationQueue cancelAllOperations];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (id)init
{
    if ((self = [super init])) {
        // When a user changes their password, subsequent HTTP operations will come back without a login cookie. So any operation might bear the news that we've been logged out.
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(networkingOperationDidStart:)
                                                     name:AFNetworkingOperationDidStartNotification
                                                   object:nil];
    }
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

+ (instancetype)sharedClient
{
    return [self client];
}

- (NSURL *)baseURL
{
    return _HTTPManager.baseURL;
}

- (void)setBaseURL:(NSURL *)baseURL
{
    if ([baseURL isEqual:self.baseURL]) {
        return;
    }
    
    [_HTTPManager.operationQueue cancelAllOperations];
    _HTTPManager = [[AwfulHTTPRequestOperationManager alloc] initWithBaseURL:baseURL];
}

- (void)setManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext) {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:NSManagedObjectContextDidSaveNotification
                                                      object:_managedObjectContext];
    }
    if (_backgroundManagedObjectContext) {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:NSManagedObjectContextDidSaveNotification
                                                      object:_backgroundManagedObjectContext];
        _backgroundManagedObjectContext = nil;
        _lastModifiedObserver = nil;
    }
    
    _managedObjectContext = managedObjectContext;
    
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
        _lastModifiedObserver = [[LastModifiedContextObserver alloc] initWithManagedObjectContext:_backgroundManagedObjectContext];
    }
}

- (void)mainManagedObjectContextDidSave:(NSNotification *)notification
{
    NSManagedObjectContext *context = _backgroundManagedObjectContext;
    [context performBlock:^{
        [context mergeChangesFromContextDidSaveNotification:notification];
    }];
}

- (void)backgroundManagedObjectContextDidSave:(NSNotification *)notification
{
    NSManagedObjectContext *context = self.managedObjectContext;
    NSArray *updatedObjectIDs = [notification.userInfo[NSUpdatedObjectsKey] valueForKey:@"objectID"];
    [context performBlock:^{
        for (NSManagedObjectID *objectID in updatedObjectIDs) {
            NSManagedObject *mainObject = [context objectWithID:objectID];
            [mainObject willAccessValueForKey:nil];
        }
        [context mergeChangesFromContextDidSaveNotification:notification];
    }];
}

- (BOOL)reachable
{
    return _HTTPManager.reachabilityManager.reachable;
}

- (BOOL)loggedIn
{
    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:_HTTPManager.baseURL];
    return [[cookies valueForKey:NSHTTPCookieName] containsObject:@"bbuserid"];
}

- (NSDate *)loginCookieExpiryDate
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
        if (self.didRemotelyLogOutBlock) {
            self.didRemotelyLogOutBlock();
        }
    }
}

#pragma mark - Sessions

- (NSOperation *)logInWithUsername:(NSString *)username
                          password:(NSString *)password
                           andThen:(void (^)(NSError *error, User *user))callback
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
            ProfileScraper *scraper = [ProfileScraper scrapeNode:document intoManagedObjectContext:managedObjectContext];
            NSError *error = scraper.error;
            if (scraper.profile) {
                [managedObjectContext save:&error];
            }
            if (callback) {
                NSManagedObjectID *objectID = scraper.profile.user.objectID;
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    User *user = [mainManagedObjectContext awful_objectWithID:objectID];
                    callback(error, user);
                }];
            }
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (operation.response.statusCode == 401) {
            NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: @"Invalid username or password",
                                        NSUnderlyingErrorKey: error };
            error = [NSError errorWithDomain:AwfulCoreError.domain
                                        code:AwfulCoreError.invalidUsernameOrPassword
                                    userInfo:userInfo];
        }
        if (callback) callback(error, nil);
    }];
}

#pragma mark - Forums

- (NSOperation *)taxonomizeForumsAndThen:(void (^)(NSError *error, NSArray *forums))callback
{
    // Seems like only forumdisplay.php and showthread.php have the <select> with a complete list of forums. We'll use the Main "forum" as it's the smallest page with the drop-down list.
    NSManagedObjectContext *managedObjectContext = _backgroundManagedObjectContext;
    NSManagedObjectContext *mainManagedObjectContext = self.managedObjectContext;
    return [_HTTPManager GET:@"forumdisplay.php"
                  parameters:@{ @"forumid": @"48" }
                     success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        [managedObjectContext performBlock:^{
            AwfulForumHierarchyScraper *scraper = [AwfulForumHierarchyScraper scrapeNode:document intoManagedObjectContext:managedObjectContext];
            NSError *error = scraper.error;
            if (scraper.forums) {
                [managedObjectContext save:&error];
            }
            if (callback) {
                NSArray *objectIDs = [scraper.forums valueForKey:@"objectID"];
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    NSArray *forums = [mainManagedObjectContext awful_objectsWithIDs:objectIDs];
                    callback(error, forums);
                }];
            }
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil);
    }];
}

#pragma mark - Threads

- (NSOperation *)listThreadsInForum:(Forum *)forum
                      withThreadTag:(ThreadTag *)threadTag
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
            AwfulThreadListScraper *scraper = [AwfulThreadListScraper scrapeNode:document intoManagedObjectContext:managedObjectContext];
            NSError *error = scraper.error;
            if (scraper.threads && !error) {
                if (page == 1) {
                    NSMutableSet *threadsToForget = [scraper.forum.threads mutableCopy];
                    for (Thread *thread in scraper.threads) {
                        [threadsToForget removeObject:thread];
                    }
                    [threadsToForget setValue:@(0) forKey:@"threadListPage"];
                }
                [scraper.threads setValue:@(page) forKey:@"threadListPage"];
                [managedObjectContext save:&error];
            }

            if (callback) {
                NSArray *objectIDs = [scraper.threads valueForKey:@"objectID"];
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
            AwfulThreadListScraper *scraper = [AwfulThreadListScraper scrapeNode:document intoManagedObjectContext:managedObjectContext];
            NSError *error = scraper.error;
            if (scraper.threads && !error) {
                [scraper.threads setValue:@YES forKey:@"bookmarked"];
                NSArray *threadIDsToIgnore = [scraper.threads valueForKey:@"threadID"];
                NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:Thread.entityName];
                fetchRequest.predicate = [NSPredicate predicateWithFormat:@"bookmarked = YES && bookmarkListPage >= %ld && NOT(threadID IN %@)", (long)page, threadIDsToIgnore];
                NSError *error;
                NSArray *threadsToForget = [managedObjectContext executeFetchRequest:fetchRequest error:&error];
                if (!threadsToForget) {
                    NSLog(@"%s error fetching: %@", __PRETTY_FUNCTION__, error);
                }
                [threadsToForget setValue:@0 forKey:@"bookmarkListPage"];
                [scraper.threads setValue:@(page) forKey:@"bookmarkListPage"];
                [managedObjectContext save:&error];
            }
            
            if (callback) {
                NSArray *objectIDs = [scraper.threads valueForKey:@"objectID"];
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

- (NSOperation *)setThread:(Thread *)thread
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

- (NSOperation *)rateThread:(Thread *)thread
                           :(NSInteger)rating
                    andThen:(void (^)(NSError *error))callback
{
    return [_HTTPManager POST:@"threadrate.php"
                   parameters:@{ @"vote": @(MAX(5, MIN(1, rating))),
                                 @"threadid": thread.threadID }
                      success:^(AFHTTPRequestOperation *operation, id responseObject)
    {
        if (callback) callback(nil);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error);
    }];
}

- (NSOperation *)markThreadReadUpToPost:(Post *)post
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

- (NSOperation *)markThreadUnread:(Thread *)thread
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
            HTMLElement *formElement = [document firstNodeMatchingSelector:@"form[name='vbform']"];
            AwfulForm *form = [[AwfulForm alloc] initWithElement:formElement];
            if (callback) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [form scrapeThreadTagsIntoManagedObjectContext:mainManagedObjectContext];
                    NSError *error;
                    if (form) {
                        [mainManagedObjectContext save:&error];
                    } else {
                        error = [NSError errorWithDomain:AwfulCoreError.domain
                                                    code:AwfulCoreError.parseError
                                                userInfo:@{ NSLocalizedDescriptionKey: @"Could not find new thread form" }];
                    }
                    callback(error, form);
                });
            }
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil);
    }];
}

- (NSOperation *)postThreadInForum:(Forum *)forum
                       withSubject:(NSString *)subject
                         threadTag:(ThreadTag *)threadTag
                      secondaryTag:(ThreadTag *)secondaryTag
                            BBcode:(NSString *)text
                           andThen:(void (^)(NSError *error, Thread *thread))callback
{
    NSManagedObjectContext *managedObjectContext = _backgroundManagedObjectContext;
    NSManagedObjectContext *mainManagedObjectContext = _managedObjectContext;
    return [_HTTPManager GET:@"newthread.php"
                  parameters:@{ @"action": @"newthread",
                                @"forumid": forum.forumID }
                     success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        [managedObjectContext performBlock:^{
            HTMLElement *formElement = [document firstNodeMatchingSelector:@"form[name='vbform']"];
            AwfulForm *form = [[AwfulForm alloc] initWithElement:formElement];
            NSMutableDictionary *parameters = [form recommendedParameters];
            if (!parameters) {
                NSError *error;
                HTMLElement *specialMessage = [document firstNodeMatchingSelector:@"#content center div.standard"];
                if (specialMessage && [specialMessage.textContent rangeOfString:@"accepting"].location != NSNotFound) {
                    error = [NSError errorWithDomain:AwfulCoreError.domain
                                                code:AwfulCoreError.forbidden
                                            userInfo:@{ NSLocalizedDescriptionKey: @"You're not allowed to post threads in this forum" }];
                } else {
                    error = [NSError errorWithDomain:AwfulCoreError.domain
                                                code:AwfulCoreError.parseError
                                            userInfo:@{ NSLocalizedDescriptionKey: @"Could not find new thread form" }];
                }
                if (callback) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        callback(error, nil);
                    });
                }
                return;
            }
            
            parameters[@"subject"] = [subject copy];
            if (threadTag.threadTagID) {
                parameters[form.selectedThreadTagKey] = threadTag.threadTagID;
            }
            parameters[@"message"] = [text copy];
            if (secondaryTag.threadTagID) {
                parameters[form.selectedSecondaryThreadTagKey] = secondaryTag.threadTagID;
            }
            [parameters removeObjectForKey:@"preview"];
            [_HTTPManager POST:@"newthread.php"
                    parameters:parameters
                       success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
             {
                 HTMLElement *link = [document firstNodeMatchingSelector:@"a[href *= 'showthread']"];
                 NSURL *URL = [NSURL URLWithString:link[@"href"]];
                 NSString *threadID = AwfulCoreQueryDictionaryWithURL(URL)[@"threadid"];
                 NSError *error;
                 Thread *thread;
                 if (threadID.length > 0) {
                     ThreadKey *threadKey = [[ThreadKey alloc] initWithThreadID:threadID];
                     thread = [Thread objectForKey:threadKey inManagedObjectContext:mainManagedObjectContext];
                 } else {
                     error = [NSError errorWithDomain:AwfulCoreError.domain code:AwfulCoreError.parseError userInfo:@{ NSLocalizedDescriptionKey: @"The new thread could not be located. Maybe it didn't actually get made. Double-check if your thread has appeared, then try again."}];
                 }
                 if (callback) callback(error, thread);
             } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                 if (callback) callback(error, nil);
             }];
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil);
    }];
}

- (NSOperation *)previewOriginalPostForThreadInForum:(Forum *)forum
                                          withBBcode:(NSString *)BBcode
                                             andThen:(void (^)(NSError *error, NSString *postHTML))callback
{
    return [_HTTPManager POST:@"newthread.php"
                   parameters:@{ @"forumid": forum.forumID,
                                 @"action": @"postthread",
                                 @"message": BBcode,
                                 @"parseurl": @"yes",
                                 @"preview": @"Preview Post" }
                      success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        HTMLElement *postbody = [document firstNodeMatchingSelector:@".postbody"];
        if (postbody) {
            WorkAroundAnnoyingImageBBcodeTagNotMatchingInPostHTML(postbody);
            if (callback) callback(nil, postbody.innerHTML);
        } else {
            NSError *error = [NSError errorWithDomain:AwfulCoreError.domain
                                                 code:AwfulCoreError.parseError
                                             userInfo:@{ NSLocalizedDescriptionKey: @"Could not find previewed original post" }];
            if (callback) callback(error, nil);
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil);
    }];
}

#pragma mark - Posts

- (NSOperation *)listPostsInThread:(Thread *)thread
                         writtenBy:(User *)author
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
        }
        return nil;
    }
    AFHTTPRequestOperation *operation = [_HTTPManager HTTPRequestOperationWithRequest:request
                                                                              success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        [managedObjectContext performBlock:^{
            AwfulPostsPageScraper *scraper = [AwfulPostsPageScraper scrapeNode:document intoManagedObjectContext:managedObjectContext];
            NSError *error = scraper.error;
            if (scraper.posts) {
                [managedObjectContext save:&error];
            }
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
                
                NSArray *objectIDs = [scraper.posts valueForKey:@"objectID"];
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    // The posts page scraper may have updated the passed-in thread, so we should make sure the passed-in thread is up-to-date. And although the AwfulForumsClient API is assumed to be called from the main thread, we cannot assume the passed-in thread's context is the same as our main thread context.
                    [thread.managedObjectContext refreshObject:thread mergeChanges:YES];
                    
                    NSArray *posts = [mainManagedObjectContext awful_objectsWithIDs:objectIDs];
                    callback(error, posts, firstUnreadPostIndex, scraper.advertisementHTML);
                });
            }
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil, NSNotFound, nil);
    }];
    
    // SA: We set perpage=40 above to effectively ignore the user's "number of posts per page" setting on the Forums proper. When we get redirected (i.e. goto=newpost or goto=lastpost), the page we're redirected to is appropriate for our hardcoded perpage=40. However, the redirected URL has **no** perpage parameter, so it defaults to the user's setting from the Forums proper. This block maintains our hardcoded perpage value.
    [operation setRedirectResponseBlock:^(NSURLConnection *connection, NSURLRequest *request, NSURLResponse *redirectResponse) {
        NSURL *URL = request.URL;
        NSMutableDictionary *queryDictionary = [AwfulCoreQueryDictionaryWithURL(URL) mutableCopy];
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

- (NSOperation *)readIgnoredPost:(Post *)post andThen:(void (^)(NSError *error))callback
{
    NSManagedObjectContext *managedObjectContext = _backgroundManagedObjectContext;
    return [_HTTPManager GET:@"showthread.php"
                  parameters:@{ @"action": @"showpost",
                                @"postid": post.postID }
                     success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        [managedObjectContext performBlock:^{
            AwfulPostScraper *scraper = [AwfulPostScraper scrapeNode:document intoManagedObjectContext:managedObjectContext];
            NSError *error = scraper.error;
            if (scraper.post) {
                [managedObjectContext save:&error];
            }
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

- (NSOperation *)replyToThread:(Thread *)thread
                    withBBcode:(NSString *)text
                       andThen:(void (^)(NSError *error, Post *post))callback
{
    NSManagedObjectContext *managedObjectContext = _backgroundManagedObjectContext;
    NSManagedObjectContext *mainManagedObjectContext = self.managedObjectContext;
    return [_HTTPManager GET:@"newreply.php"
                  parameters:@{ @"action" : @"newreply",
                                @"threadid" : thread.threadID }
                     success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        [managedObjectContext performBlock:^{
            HTMLElement *formElement = [document firstNodeMatchingSelector:@"form[name='vbform']"];
            AwfulForm *form = [[AwfulForm alloc] initWithElement:formElement];
            if (!form) {
                if (callback) {
                    NSString *description;
                    if (thread.closed) {
                        description = @"Could not reply; the thread may be closed.";
                    } else {
                        description = @"Could not reply; failed to find the form.";
                    }
                    NSError *error = [NSError errorWithDomain:AwfulCoreError.domain
                                                         code:AwfulCoreError.parseError
                                                     userInfo:@{ NSLocalizedDescriptionKey: description }];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        callback(error, nil);
                    });
                }
                return;
            }
            NSMutableDictionary *parameters = [form recommendedParameters];
            parameters[@"message"] = text;
            [parameters removeObjectForKey:@"preview"];
            [_HTTPManager POST:@"newreply.php"
                    parameters:parameters
                       success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
             {
                 Post *post;
                 HTMLElement *link = ([document firstNodeMatchingSelector:@"a[href *= 'goto=post']"] ?:
                                      [document firstNodeMatchingSelector:@"a[href *= 'goto=lastpost']"]);
                 NSURL *URL = [NSURL URLWithString:link[@"href"]];
                 NSDictionary *queryDictionary = AwfulCoreQueryDictionaryWithURL(URL);
                 if ([queryDictionary[@"goto"] isEqual:@"post"]) {
                     NSString *postID = queryDictionary[@"postid"];
                     if (postID.length > 0) {
                         PostKey *postKey = [[PostKey alloc] initWithPostID:postID];
                         post = [Post objectForKey:postKey inManagedObjectContext:mainManagedObjectContext];
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

- (NSOperation *)previewReplyToThread:(Thread *)thread
                           withBBcode:(NSString *)BBcode
                              andThen:(void (^)(NSError *error, NSString *postHTML))callback
{
    return [_HTTPManager POST:@"newreply.php"
                   parameters:@{ @"action": @"postreply",
                                 @"threadid": thread.threadID,
                                 @"message": BBcode,
                                 @"parseurl": @"yes",
                                 @"preview": @"Preview Reply" }
                      success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        HTMLElement *element = [document firstNodeMatchingSelector:@".postbody"];
        if (element) {
            WorkAroundAnnoyingImageBBcodeTagNotMatchingInPostHTML(element);
            if (callback) callback(nil, element.innerHTML);
        } else {
            NSError *error = [NSError errorWithDomain:AwfulCoreError.domain
                                                 code:AwfulCoreError.parseError
                                             userInfo:@{ NSLocalizedDescriptionKey: @"Could not find previewed post" }];
            if (callback) callback(error, nil);
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil);
    }];
}

- (NSOperation *)findBBcodeContentsWithPost:(Post *)post
                                    andThen:(void (^)(NSError *error, NSString *text))callback
{
    NSManagedObjectContext *managedObjectContext = _backgroundManagedObjectContext;
    return [_HTTPManager GET:@"editpost.php"
                  parameters:@{ @"action": @"editpost",
                                @"postid": post.postID }
                     success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        [managedObjectContext performBlock:^{
            HTMLElement *formElement = [document firstNodeMatchingSelector:@"form[name='vbform']"];
            AwfulForm *form = [[AwfulForm alloc] initWithElement:formElement];
            NSString *message = form.allParameters[@"message"];
            NSError *error;
            if (!message) {
                if (form) {
                    error = [NSError errorWithDomain:AwfulCoreError.domain
                                                code:AwfulCoreError.parseError
                                            userInfo:@{ NSLocalizedDescriptionKey: @"Could not find post contents in edit post form" }];
                } else {
                    error = [NSError errorWithDomain:AwfulCoreError.domain
                                                code:AwfulCoreError.parseError
                                            userInfo:@{ NSLocalizedDescriptionKey: @"Could not find edit post form" }];
                }
            }
            if (callback) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    callback(error, message);
                });
            }
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil);
    }];
}

- (NSOperation *)quoteBBcodeContentsWithPost:(Post *)post
                                     andThen:(void (^)(NSError *error, NSString *quotedText))callback
{
    NSManagedObjectContext *managedObjectContext = _backgroundManagedObjectContext;
    return [_HTTPManager GET:@"newreply.php"
                  parameters:@{ @"action": @"newreply",
                                @"postid": post.postID }
                     success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        if (!callback) return;
        [managedObjectContext performBlock:^{
            HTMLElement *formElement = [document firstNodeMatchingSelector:@"form[name='vbform']"];
            AwfulForm *form = [[AwfulForm alloc] initWithElement:formElement];
            NSString *BBcode = form.allParameters[@"message"];
            NSError *error;
            if (!BBcode) {
                HTMLElement *specialMessage = [document firstNodeMatchingSelector:@"#content center div.standard"];
                if (specialMessage && [specialMessage.textContent rangeOfString:@"permission"].location != NSNotFound) {
                    error = [NSError errorWithDomain:AwfulCoreError.domain
                                                code:AwfulCoreError.forbidden
                                            userInfo:@{ NSLocalizedDescriptionKey: @"You're not allowed to post in this thread" }];
                } else {
                    error = [NSError errorWithDomain:AwfulCoreError.domain
                                                code:AwfulCoreError.parseError
                                            userInfo:@{ NSLocalizedDescriptionKey: @"Failed to quote post; could not find form" }];
                }
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                callback(error, BBcode);
            });
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil);
    }];
}

- (NSOperation *)editPost:(Post *)post
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
            HTMLElement *formElement = [document firstNodeMatchingSelector:@"form[name='vbform']"];
            AwfulForm *form = [[AwfulForm alloc] initWithElement:formElement];
            NSMutableDictionary *parameters = [form recommendedParameters];
            if (!parameters[@"postid"]) {
                if (callback) {
                    NSError *error;
                    HTMLElement *specialMessage = [document firstNodeMatchingSelector:@"#content center div.standard"];
                    if (specialMessage && [specialMessage.textContent rangeOfString:@"permission"].location != NSNotFound) {
                        error = [NSError errorWithDomain:AwfulCoreError.domain
                                                    code:AwfulCoreError.forbidden
                                                userInfo:@{ NSLocalizedDescriptionKey: @"You're not allowed to edit posts in this thread" }];
                    } else {
                        error = [NSError errorWithDomain:AwfulCoreError.domain
                                                    code:AwfulCoreError.parseError
                                                userInfo:@{ NSLocalizedDescriptionKey: @"Failed to edit post; could not find form" }];
                    }
                    dispatch_async(dispatch_get_main_queue(), ^{
                        callback(error);
                    });
                }
                return;
            }
            parameters[@"message"] = text;
            [parameters removeObjectForKey:@"preview"];
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

- (NSOperation *)previewEditToPost:(Post *)post
                        withBBcode:(NSString *)BBcode
                           andThen:(void (^)(NSError *error, NSString *postHTML))callback
{
    return [_HTTPManager POST:@"editpost.php"
                   parameters:@{ @"action": @"updatepost",
                                 @"postid": post.postID,
                                 @"message": BBcode,
                                 @"parseurl": @"yes",
                                 @"preview": @"Preview Post" }
                      success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        HTMLElement *postbody = [document firstNodeMatchingSelector:@".postbody"];
        if (postbody) {
            WorkAroundAnnoyingImageBBcodeTagNotMatchingInPostHTML(postbody);
            if (callback) callback(nil, postbody.innerHTML);
        } else {
            NSError *error = [NSError errorWithDomain:AwfulCoreError.domain
                                                 code:AwfulCoreError.parseError
                                             userInfo:@{ NSLocalizedDescriptionKey: @"Could not find previewd post" }];
            if (callback) callback(error, nil);
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil);
    }];
}

static void WorkAroundAnnoyingImageBBcodeTagNotMatchingInPostHTML(HTMLElement *postbody)
{
    for (HTMLElement *img in [postbody nodesMatchingSelector:@"img[src^='http://awful-image']"]) {
        NSString *src = img[@"src"];
        src = [src substringFromIndex:@"http://".length];
        img[@"src"] = src;
    }
}

- (NSOperation *)locatePostWithID:(NSString *)postID
                          andThen:(void (^)(NSError *error, Post *post, AwfulThreadPage page))callback
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
            NSError *error = [NSError errorWithDomain:AwfulCoreError.domain
                                                 code:AwfulCoreError.parseError
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
        NSDictionary *query = AwfulCoreQueryDictionaryWithURL(request.URL);
        if ([query[@"threadid"] length] > 0 && [query[@"pagenumber"] integerValue] != 0) {
            [managedObjectContext performBlock:^{
                PostKey *postKey = [[PostKey alloc] initWithPostID:postID];
                Post *post = [Post objectForKey:postKey inManagedObjectContext:managedObjectContext];
                ThreadKey *threadKey = [[ThreadKey alloc] initWithThreadID:query[@"threadid"]];
                post.thread = [Thread objectForKey:threadKey inManagedObjectContext:managedObjectContext];
                NSError *error;
                BOOL ok = [managedObjectContext save:&error];
                if (callback) {
                    NSManagedObjectID *objectID = post.objectID;
                    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                        if (ok) {
                            Post *post = [mainManagedObjectContext awful_objectWithID:objectID];
                            callback(nil, post, [query[@"pagenumber"] integerValue]);
                        } else {
                            NSString *message = @"The post's thread could not be parsed";
                            NSError *underlyingError = error;
                            NSError *error = [NSError errorWithDomain:AwfulCoreError.domain
                                                                 code:AwfulCoreError.parseError
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
                NSError *error = [NSError errorWithDomain:AwfulCoreError.domain
                                                     code:AwfulCoreError.parseError
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

- (NSOperation *)reportPost:(Post *)post
                 withReason:(NSString *)reason
                    andThen:(void (^)(NSError *error))callback
{
    NSMutableDictionary *parameters = [NSMutableDictionary new];
    parameters[@"action"] = @"submit";
    parameters[@"postid"] = post.postID;
    parameters[@"comments"] = reason.length > 60 ? [reason substringToIndex:60] : (reason ?: @"");
    return [_HTTPManager POST:@"modalert.php" parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        // Error checking is intentionally lax here. Let plat non-havers spin their wheels.
        if (callback) callback(nil);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error);
    }];
}

#pragma mark - People

- (NSOperation *)learnLoggedInUserInfoAndThen:(void (^)(NSError *error, User *user))callback
{
    NSManagedObjectContext *managedObjectContext = _backgroundManagedObjectContext;
    NSManagedObjectContext *mainManagedObjectContext = self.managedObjectContext;
    return [_HTTPManager GET:@"member.php"
                  parameters:@{ @"action": @"getinfo" }
                     success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        [managedObjectContext performBlock:^{
            ProfileScraper *scraper = [ProfileScraper scrapeNode:document intoManagedObjectContext:managedObjectContext];
            NSError *error = scraper.error;
            User *user = scraper.profile.user;
            if (user) {
                [managedObjectContext save:&error];
            }
            if (callback) {
                NSManagedObjectID *objectID = user.objectID;
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    User *user = [mainManagedObjectContext awful_objectWithID:objectID];
                    callback(error, user);
                }];
            }
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil);
    }];
}

- (NSOperation *)profileUserWithID:(NSString *)userID
                          username:(NSString *)username
                           andThen:(void (^)(NSError *error, Profile *profile))callback
{
    NSParameterAssert(userID.length > 0 || username.length > 0);
    
    NSMutableDictionary *parameters = [NSMutableDictionary new];
    parameters[@"action"] = @"getinfo";
    if (userID.length > 0) {
        parameters[@"userid"] = userID;
    } else {
        parameters[@"username"] = username;
    }
    
    NSManagedObjectContext *managedObjectContext = _backgroundManagedObjectContext;
    NSManagedObjectContext *mainManagedObjectContext = self.managedObjectContext;
    return [_HTTPManager GET:@"member.php"
                  parameters:parameters
                     success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        [managedObjectContext performBlock:^{
            ProfileScraper *scraper = [ProfileScraper scrapeNode:document intoManagedObjectContext:managedObjectContext];
            NSError *error = scraper.error;
            if (scraper.profile) {
                [managedObjectContext save:&error];
            }
            if (callback) {
                NSManagedObjectID *objectID = scraper.profile.objectID;
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    Profile *profile = [mainManagedObjectContext awful_objectWithID:objectID];
                    callback(error, profile);
                }];
            }
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil);
    }];
}

#pragma mark - Punishments

- (NSOperation *)listPunishmentsOnPage:(NSInteger)page
                               forUser:(User *)user
                               andThen:(void (^)(NSError *error, NSArray *bans))callback
{
    NSOperation * (^doIt)() = ^(User *user) {
        NSMutableDictionary *parameters = [@{ @"pagenumber": @(page) } mutableCopy];
        if (user.userID.length > 0) {
            parameters[@"userid"] = user.userID;
        }
        NSManagedObjectContext *mainManagedObjectContext = self.managedObjectContext;
        return [_HTTPManager GET:@"banlist.php"
                      parameters:parameters
                         success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
        {
             [mainManagedObjectContext performBlock:^{
                 LepersColonyPageScraper *scraper = [LepersColonyPageScraper scrapeNode:document intoManagedObjectContext:mainManagedObjectContext];
                 NSError *error = scraper.error;
                 if (scraper.punishments) {
                     [mainManagedObjectContext save:&error];
                 }
                 if (callback) {
                     callback(error, scraper.punishments);
                 }
             }];
         } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
             if (callback) callback(error, nil);
         }];
    };
    
    if (user.userID.length == 0 && user.username.length > 0) {
        return [self profileUserWithID:nil username:user.username andThen:^(NSError *error, Profile *profile) {
            if (error) {
                if (callback) callback(error, nil);
            } else {
                doIt(user);
            }
        }];
    } else {
        return doIt(user);
    }
}

#pragma mark - Private Messages

- (NSOperation *)countUnreadPrivateMessagesInInboxAndThen:(void (^)(NSError *error, NSInteger unreadMessageCount))callback
{
    // Not readlly doing anything with the background managed object context, just using its queue.
    NSManagedObjectContext *managedObjectContext = _backgroundManagedObjectContext;
    
    return [_HTTPManager GET:@"private.php"
                  parameters:nil
                     success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        [managedObjectContext performBlock:^{
            AwfulUnreadPrivateMessageCountScraper *scraper = [AwfulUnreadPrivateMessageCountScraper scrapeNode:document
                                                                                      intoManagedObjectContext:managedObjectContext];
            if (callback) {
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    callback(scraper.error, scraper.unreadPrivateMessageCount);
                }];
            }
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, 0);
    }];
}

- (NSOperation *)listPrivateMessageInboxAndThen:(void (^)(NSError *error, NSArray *messages))callback
{
    NSManagedObjectContext *managedObjectContext = _backgroundManagedObjectContext;
    NSManagedObjectContext *mainManagedObjectContext = self.managedObjectContext;
    return [_HTTPManager GET:@"private.php"
                  parameters:nil
                     success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        [managedObjectContext performBlock:^{
            PrivateMessageFolderScraper *scraper = [PrivateMessageFolderScraper scrapeNode:document
                                                                  intoManagedObjectContext:managedObjectContext];
            NSError *error = scraper.error;
            if (scraper.messages) {
                [managedObjectContext save:&error];
            }
            if (callback) {
                NSArray *objectIDs = [scraper.messages valueForKey:@"objectID"];
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

- (NSOperation *)deletePrivateMessage:(PrivateMessage *)message
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

- (NSOperation *)readPrivateMessageWithKey:(PrivateMessageKey *)messageKey
                                   andThen:(void (^)(NSError *error, PrivateMessage *message))callback
{
    NSManagedObjectContext *managedObjectContext = _backgroundManagedObjectContext;
    NSManagedObjectContext *mainManagedObjectContext = self.managedObjectContext;
    return [_HTTPManager GET:@"private.php"
                  parameters:@{ @"action": @"show",
                                @"privatemessageid": messageKey.messageID }
                     success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        [managedObjectContext performBlock:^{
            PrivateMessageScraper *scraper = [PrivateMessageScraper scrapeNode:document intoManagedObjectContext:managedObjectContext];
            NSError *error = scraper.error;
            if (scraper.privateMessage) {
                [managedObjectContext save:&error];
            }
            if (callback) {
                NSManagedObjectID *objectID = scraper.privateMessage.objectID;
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    PrivateMessage *message = objectID ? [mainManagedObjectContext awful_objectWithID:objectID] : nil;
                    callback(error, message);
                }];
            }
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil);
    }];
}

- (NSOperation *)quoteBBcodeContentsOfPrivateMessage:(PrivateMessage *)message
                                             andThen:(void (^)(NSError *error, NSString *BBcode))callback
{
    NSManagedObjectContext *managedObjectContext = _backgroundManagedObjectContext;
    return [_HTTPManager GET:@"private.php"
                  parameters:@{ @"action": @"newmessage",
                                @"privatemessageid": message.messageID }
                     success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        [managedObjectContext performBlock:^{
            HTMLElement *formElement = [document firstNodeMatchingSelector:@"form[name='vbform']"];
            AwfulForm *form = [[AwfulForm alloc] initWithElement:formElement];
            NSString *message = form.allParameters[@"message"];
            NSError *error;
            if (!message) {
                NSString *description;
                if (form) {
                    description = @"Failed quoting private message; could not find text box";
                } else {
                    description = @"Failed quoting private message; could not find form";
                }
                error = [NSError errorWithDomain:AwfulCoreError.domain
                                            code:AwfulCoreError.parseError
                                        userInfo:@{ NSLocalizedDescriptionKey: description }];
            }
            if (callback) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    callback(error, message);
                });
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
            HTMLElement *formElement = [document firstNodeMatchingSelector:@"form[name='vbform']"];
            AwfulForm *form = [[AwfulForm alloc] initWithElement:formElement];
            [form scrapeThreadTagsIntoManagedObjectContext:managedObjectContext];
            if (form.threadTags) {
                NSError *error;
                [managedObjectContext save:&error];
                if (callback) {
                    NSArray *objectIDs = [form.threadTags valueForKey:@"objectID"];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        NSArray *tags = [mainManagedObjectContext awful_objectsWithIDs:objectIDs];
                        callback(error, tags);
                    });
                }
            } else {
                if (callback) {
                    NSString *description;
                    if (form) {
                        description = @"Failed scraping thread tags from new private message form";
                    } else {
                        description = @"Could not find new private message form";
                    }
                    NSError *error = [NSError errorWithDomain:AwfulCoreError.domain
                                                         code:AwfulCoreError.parseError
                                                     userInfo:@{ NSLocalizedDescriptionKey: description }];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        callback(error, nil);
                    });
                }
            }
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil);
    }];
}

- (NSOperation *)sendPrivateMessageTo:(NSString *)username
                          withSubject:(NSString *)subject
                            threadTag:(ThreadTag *)threadTag
                               BBcode:(NSString *)text
                     asReplyToMessage:(PrivateMessage *)regardingMessage
                 forwardedFromMessage:(PrivateMessage *)forwardedMessage
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
                      success:^(AFHTTPRequestOperation *operation, id responseObject)
    {
        if (callback) callback(nil);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error);
    }];
}

@end

@implementation NSManagedObjectContext (AwfulConvenient)

- (id)awful_objectWithID:(NSManagedObjectID *)objectID
{
    if (!objectID) return nil;
    return (id)[self objectWithID:objectID];
}

- (NSArray *)awful_objectsWithIDs:(NSArray *)objectIDs
{
    NSMutableArray *objects = [NSMutableArray new];
    for (NSManagedObjectID *objectID in objectIDs) {
        NSManagedObject *object = [self objectWithID:objectID];
        [objects addObject:object];
    }
    return objects;
}

@end
