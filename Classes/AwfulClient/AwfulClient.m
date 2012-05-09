//
//  AwfulClient.m
//  Awful
//
//  Created by Nolan Waite on 12-05-03.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulClient.h"
#import "AwfulHTTPOperation.h"
#import "AwfulScrapeOperation.h"
#import "AwfulPersistOperation.h"

@interface AwfulClient ()

@property (strong) NSManagedObjectContext *managedObjectContext;

@property (strong) NSOperationQueue *httpQueue;
@property (strong) NSOperationQueue *scrapeQueue;
@property (strong) NSOperationQueue *persistQueue;

@end

@implementation AwfulClient

+ (AwfulClient *)sharedClient
{
    static AwfulClient *client;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSManagedObjectContext *context = ApplicationDelegate.managedObjectContext;
        client = [[AwfulClient alloc] initWithManagedObjectContext:context];
    });
    return client;
}

// Designated initializer.
- (id)initWithManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    self = [super init];
    if (self)
    {
        self.managedObjectContext = managedObjectContext;
        self.httpQueue = [NSOperationQueue new];
        self.scrapeQueue = [NSOperationQueue new];
        self.persistQueue = [NSOperationQueue new];
        // Minimize merge conflicts
        self.persistQueue.maxConcurrentOperationCount = 1;
    }
    return self;
}

@synthesize managedObjectContext = _managedObjectContext;

@synthesize httpQueue = _httpQueue;
@synthesize scrapeQueue = _scrapeQueue;
@synthesize persistQueue = _persistQueue;

#pragma mark - Log in, log out, and user info

- (void)logInAsUsername:(NSString *)username
           withPassword:(NSString *)password
                andThen:(void (^)(NSError *error, NSString *username))callback
{
    
}

- (void)logOutAndThen:(void (^)(NSError *error))callback
{
    
}

@synthesize loggedIn = _loggedIn;

- (void)fetchLoggedInUserAndThen:(void (^)(NSError *error, AwfulUser *user))callback
{
    
}

#pragma mark - Forums

- (void)fetchForumsListAndThen:(void (^)(NSError *error, NSArray *forumObjectIDs))callback
{
    // Example usage:
    
    // Make an HTTP operation.
    NSURL *url = [NSURL URLWithString:@"http://forums.somethingawful.com/forumdisplay.php?forumid=1"];
    AwfulHTTPOperation *httpOperation = [[AwfulHTTPOperation alloc] initWithURL:url];
    
    // Make a scrape operation dependent on the HTTP operation.
    AwfulForumListScrapeOperation *scrapeOperation = [AwfulForumListScrapeOperation new];
    [scrapeOperation addDependency:httpOperation];
    
    // Make a persist operation dependent on the scrape operation.
    AwfulPersistOperation *persistOperation = [[AwfulPersistOperation alloc] initWithManagedObjectContext:self.managedObjectContext];
    [persistOperation addDependency:scrapeOperation];
    
    // By setting dependencies, each operation can get the data it needs from its dependencies.
    // They'll also propagate errors/cancellations
    
    [self.httpQueue addOperation:httpOperation];
    [self.scrapeQueue addOperation:scrapeOperation];
    [self.persistQueue addOperation:persistOperation];
    
    if (!callback)
        return;
    
    dispatch_queue_t callbackQueue = dispatch_get_current_queue();
    __weak AwfulPersistOperation *blockPersist = persistOperation;
    persistOperation.completionBlock = ^{
        if ([blockPersist isCancelled] || blockPersist.error)
        {
            NSError *error = blockPersist.error;
            if (!error)
            {
                error = [NSError errorWithDomain:AwfulClientErrorDomain
                                            code:AwfulClientErrorCodes.Cancelled
                                        userInfo:nil];
            }
            dispatch_async(callbackQueue, ^{ callback(error, nil); });
        }
        else
        {
            dispatch_async(callbackQueue, ^{
                // TODO update logged-in user info if present (nearly every page has it)
                callback(nil, nil /* TODO some array */);
            });
        }
    };
}

#pragma mark - Threads

- (void)fetchThreadsInForum:(AwfulForum *)forum
                     onPage:(NSInteger)pageNumber
                    andThen:(void (^)(NSError *error, NSArray *threads))callback
{
    
}

- (void)fetchBookmarksOnPage:(NSInteger)pageNumber
                     andThen:(void (^)(NSError *error, NSArray *bookmarks))callback
{
    
}

- (void)bookmarkThread:(AwfulThread *)thread andThen:(void (^)(NSError *error))callback
{
    
}

- (void)removeBookmark:(AwfulThread *)thread andThen:(void (^)(NSError *error))callback
{
    
}

- (void)vote:(NSInteger)vote
    onThread:(AwfulThread *)thread
     andThen:(void (^)(NSError *error))callback
{
    
}

// TODO mark thread seen

- (void)markThreadUnseen:(AwfulThread *)thread andThen:(void (^)(NSError *error))callback
{
    
}

#pragma mark - Posts

- (void)fetchPostsInThread:(AwfulThread *)thread
                    onPage:(NSInteger)pageNumber
                   andThen:(void (^)(NSError *error, NSArray *posts))callback
{
    
}

- (void)post:(NSString *)post
    inThread:(AwfulThread *)thread
     andThen:(void (^)(NSError *error))callback
{
    
}

- (void)editPost:(AwfulPost *)post
        withPost:(NSString *)emendedPost
         andThen:(void (^)(NSError *error))callback
{
    
}

- (void)quotePost:(AwfulPost *)post andThen:(void (^)(NSError *error, NSString *quote))callback
{
    
}

@end

#pragma mark - Errors

NSString * const AwfulClientErrorDomain = @"AwfulClient error domain";

const struct AwfulClientErrorCodes AwfulClientErrorCodes =
{
    .Cancelled = 1,
};
