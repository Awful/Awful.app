//
//  AwfulClient.h
//  Awful
//
//  Created by Nolan Waite on 12-05-03.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AwfulForum;
@class AwfulThread;
@class AwfulPost;
@class AwfulUser;

@interface AwfulClient : NSObject

+ (AwfulClient *)sharedClient;

// Designated initializer.
- (id)initWithManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

// For each callback, if the error parameter is nil then the operation was successful.
// All errors will be in the AwfulClientErrorDomain and will have one of the error codes listed.

// Callbacks are run on the same queue that called into AwfulClient.

#pragma mark - Log in, log out, and user info

- (void)logInAsUsername:(NSString *)username
           withPassword:(NSString *)password
                andThen:(void (^)(NSError *error, NSString *username))callback;

- (void)logOutAndThen:(void (^)(NSError *error))callback;

@property (readonly, getter = isLoggedIn) BOOL loggedIn;

- (void)fetchLoggedInUserAndThen:(void (^)(NSError *error, AwfulUser *user))callback;

#pragma mark - Forums

- (void)fetchForumsListAndThen:(void (^)(NSError *error, NSArray *forumObjectIDs))callback;

#pragma mark - Threads

- (void)fetchThreadsInForum:(AwfulForum *)forum
                     onPage:(NSInteger)pageNumber
                    andThen:(void (^)(NSError *error, NSArray *threads))callback;

- (void)fetchBookmarksOnPage:(NSInteger)pageNumber
                     andThen:(void (^)(NSError *error, NSArray *bookmarks))callback;

- (void)bookmarkThread:(AwfulThread *)thread andThen:(void (^)(NSError *error))callback;

- (void)removeBookmark:(AwfulThread *)thread andThen:(void (^)(NSError *error))callback;

- (void)vote:(NSInteger)vote
    onThread:(AwfulThread *)thread
     andThen:(void (^)(NSError *error))callback;

// TODO mark thread seen

- (void)markThreadUnseen:(AwfulThread *)thread andThen:(void (^)(NSError *error))callback;

#pragma mark - Posts

- (void)fetchPostsInThread:(AwfulThread *)thread
                    onPage:(NSInteger)pageNumber
                   andThen:(void (^)(NSError *error, NSArray *posts))callback;

- (void)post:(NSString *)post
    inThread:(AwfulThread *)thread
     andThen:(void (^)(NSError *error))callback;

- (void)editPost:(AwfulPost *)post
        withPost:(NSString *)emendedPost
         andThen:(void (^)(NSError *error))callback;

- (void)quotePost:(AwfulPost *)post andThen:(void (^)(NSError *error, NSString *quote))callback;

@end

#pragma mark - Errors

extern NSString * const AwfulClientErrorDomain;

const struct AwfulClientErrorCodes
{
    const NSInteger Cancelled;
} AwfulClientErrorCodes;
