//  AwfulForumsClient.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <Foundation/Foundation.h>
#import "AwfulForm.h"
#import "AwfulModels.h"

@interface AwfulForumsClient : NSObject

// Singleton instance.
+ (AwfulForumsClient *)client;

@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;

// Cancel all operations and recreate internal HTTP client using base URL from settings.
- (void)reset;

// Returns YES if the forums are reachable through current network settings.
@property (readonly, getter=isReachable, nonatomic) BOOL reachable;

// Returns YES if someone is currently logged in to the SA Forums.
@property (readonly, getter=isLoggedIn, nonatomic) BOOL loggedIn;

// Returns the date on which the login cookie will expire.
@property (readonly, nonatomic) NSDate* loginCookieExpiryDate;

/**
 * @param threadTag A thread tag to use for filtering forums, or nil for no filtering.
 * @param callback  A block to call after listing the threads which takes two parameters: an NSError object on failure or nil on success; and an array of AwfulThread objects on success or nil on failure.
 *
 * @return An enqueued network operation.
 */
- (NSOperation *)listThreadsInForum:(AwfulForum *)forum
                      withThreadTag:(AwfulThreadTag *)threadTag
                             onPage:(NSInteger)page
                            andThen:(void (^)(NSError *error, NSArray *threads))callback;

/**
 * @param callback A block to call after listing the threads which takes two parameters: an NSError object on failure or nil on success; and an array of AwfulThread objects on success or nil on failure.
 *
 * @return An enqueued network operation.
 */
- (NSOperation *)listBookmarkedThreadsOnPage:(NSInteger)page
                                     andThen:(void (^)(NSError *error, NSArray *threads))callback;

/**
 * @param author   An AwfulUser object whose posts are the only ones listed. If nil, posts from all authors are listed.
 * @param callback A block to call after listing posts, which takes as parameters: an NSError object on failure, or nil on success; an array of AwfulPost objects on success, or nil on failure; the index of the first unread post in the posts array on success; and the banner ad HTML on success.
 *
 * @return An enqueued network operation.
 */
- (NSOperation *)listPostsInThread:(AwfulThread *)thread
                         writtenBy:(AwfulUser *)author
                            onPage:(AwfulThreadPage)page
                           andThen:(void (^)(NSError *error, NSArray *posts, NSUInteger firstUnreadPost, NSString *advertisementHTML))callback;

/**
 * @param callback A block to call after learning user info, which takes as parameters: an NSError object on failure or nil on success; and an AwfulUser object for the logged-in user on success, or nil on failure.
 *
 * @return An enqueued network operation.
 */
- (NSOperation *)learnLoggedInUserInfoAndThen:(void (^)(NSError *error, AwfulUser *user))callback;

/**
 * @param callback A block to call after (un)bookmarking the thread, which takes an NSError object as a parameter on failure, or nil on success.
 *
 * @return An enqueued network operation.
 */
- (NSOperation *)setThread:(AwfulThread *)thread
              isBookmarked:(BOOL)isBookmarked
                   andThen:(void (^)(NSError *error))callback;

/**
 * @param callback A block to call after finding the forum hierarchy which takes as parameters: an NSError object on failure or nil on success; and an array of AwfulCategory objects on success or nil on failure.
 *
 * @return An enqueued network operation.
 */
- (NSOperation *)taxonomizeForumsAndThen:(void (^)(NSError *error, NSArray *categories))callback;

/**
 * @param callback A block to call after sending the reply, which takes as parameters: an NSError object on failure, or nil on success; and the newly-created AwfulPost object on success, or nil on failure.
 *
 * @return An enqueued network operation.
 */
- (NSOperation *)replyToThread:(AwfulThread *)thread
                    withBBcode:(NSString *)text
                       andThen:(void (^)(NSError *error, AwfulPost *post))callback;

/**
 * @param callback A block to call after finding the text of the post, which takes as parameters: an NSError object on failure, or nil on success; and the BBcode text of the post on success, or nil on failure.
 *
 * @return An enqueued network operation.
 */
- (NSOperation *)findBBcodeContentsWithPost:(AwfulPost *)post
                                    andThen:(void (^)(NSError *error, NSString *text))callback;

/**
 * @param callback A block to call after finding the quoted text of the post, which takes as parameters: an NSError object on failure, or nil on success; and the BBcode quoted text of the post on success, or nil on failure.
 *
 * @return An enqueued network operation.
 */
- (NSOperation *)quoteBBcodeContentsWithPost:(AwfulPost *)post
                                     andThen:(void (^)(NSError *error, NSString *quotedText))callback;

/**
 * @param callback A block to call after editing the post, which takes as a parameter an NSError object on failure or nil on success.
 *
 * @return An enqueued network operation.
 */
- (NSOperation *)editPost:(AwfulPost *)post
                setBBcode:(NSString *)text
                  andThen:(void (^)(NSError *error))callback;

/**
 * @param callback A block to call after rating the thread, which takes as a parameter an NSError object on failure or nil on success.
 *
 * @return An enqueued network operation.
 */
- (NSOperation *)rateThread:(AwfulThread *)thread
                           :(NSInteger)rating
                    andThen:(void (^)(NSError *error))callback;

/**
 * @param callback A block to call after marking the thread read, which takes as a parameter an NSError object on failure or nil on success.
 *
 * @return An enqueued network operation.
 */
- (NSOperation *)markThreadReadUpToPost:(AwfulPost *)post
                                andThen:(void (^)(NSError *error))callback;

/**
 * @param callback A block to call after marking the thread unread, which takes as a parameter an NSError object on failure or nil on success.
 *
 * @return An enqueued network operation.
 */
- (NSOperation *)markThreadUnread:(AwfulThread *)thread
                          andThen:(void (^)(NSError *error))callback;

/**
 * @param callback A block to call after logging in, which takes as parameters: an NSError object on failure, or nil on success; and an AwfulUser object on success or nil on failure.
 *
 * @return An enqueued network operation.
 */
- (NSOperation *)logInWithUsername:(NSString *)username
                          password:(NSString *)password
                           andThen:(void (^)(NSError *error, AwfulUser *user))callback;

/**
 * @param postID   The post's ID. Specified directly in case no such post exists, which would make for a useless AwfulPost object.
 * @param callback A block to call after locating the post, which takes as parameters: an NSError object on failure or nil on success; an AwfulPost object on success or nil on failure; and the page containing the post (may be AwfulThreadPageLast).
 *
 * @return An enqueued network operation.
 */
- (NSOperation *)locatePostWithID:(NSString *)postID
                          andThen:(void (^)(NSError *error, AwfulPost *post, AwfulThreadPage page))callback;

/**
 * @param userID   The user's ID. Specified directly in case no such user exists, which would make for a useless AwfulUser object.
 * @param callback A block to call after learning of the user's info, which takes as parameters: an NSError object on failure or nil on success; and an AwfulUser object on success or nil on failure.
 *
 * @return An enqueued network operation.
 */
- (NSOperation *)profileUserWithID:(NSString *)userID
                           andThen:(void (^)(NSError *error, AwfulUser *user))callback;

/**
 * @param callback A block to call after listing bans and probations, which takes as parameters: an NSError object on failure or nil on success; and an array of AwfulBan objects on success, or nil on failure.
 *
 * @return An enqueued network operation.
 */
- (NSOperation *)listBansOnPage:(NSInteger)page
                        forUser:(AwfulUser *)user
                        andThen:(void (^)(NSError *error, NSArray *bans))callback;

/**
 * @param callback A block to call after listing the logged-in user's PM inbox, which takes as parameters: an NSError object on failure, or nil on success; and an array of AwfulPrivateMessage objects on success, or nil on failure.
 *
 * @return An enqueued network operation.
 */
- (NSOperation *)listPrivateMessageInboxAndThen:(void (^)(NSError *error, NSArray *messages))callback;

/**
 * @param callback A block to call after deleting the message, which takes as a parameter an NSError object on failure, or nil on success.
 *
 * @return An enqueued network operation.
 */
- (NSOperation *)deletePrivateMessage:(AwfulPrivateMessage *)message
                              andThen:(void (^)(NSError *error))callback;

/**
 * @param callback A block to call after reading the message, which takes as a parameter an NSError object on failure, or nil on success.
 *
 * @return An enqueued network operation.
 */
- (NSOperation *)readPrivateMessage:(AwfulPrivateMessage *)message
                            andThen:(void (^)(NSError *error))callback;

/**
 * @param callback A block to call after quoting the message, which takes as parameters: an NSError object on failure or nil on success; and the quoted BBcode contents on success or nil on failure.
 *
 * @return An enqueued network operation.
 */
- (NSOperation *)quoteBBcodeContentsOfPrivateMessage:(AwfulPrivateMessage *)message
                                             andThen:(void (^)(NSError *error, NSString *BBcode))callback;

/**
 * @param callback A block to call after listing thread tags, which takes as parameters: an NSError object on failure, or nil on success; and an array of AwfulThreadTag objects on success, or nil on failure.
 *
 * @return An enqueued network operation.
 */
- (NSOperation *)listAvailablePrivateMessageThreadTagsAndThen:(void (^)(NSError *error, NSArray *threadTags))callback;

/**
 * @param username         Requiring an AwfulUser is unhelpful as the username is typed in and may not actually exist.
 * @param threadTag        Can be nil.
 * @param regardingMessage Can be nil. Should be nil if forwardedMessage is non-nil.
 * @param forwardedMessage Can be nil. Should be nil if regardingMessage is non-nil.
 * @param callback         A block to call after sending the message, which takes as a parameter an NSError on failure, or nil on success.
 *
 * @return An enqueued network operation.
 */
- (NSOperation *)sendPrivateMessageTo:(NSString *)username
                          withSubject:(NSString *)subject
                            threadTag:(AwfulThreadTag *)threadTag
                               BBcode:(NSString *)text
                     asReplyToMessage:(AwfulPrivateMessage *)regardingMessage
                 forwardedFromMessage:(AwfulPrivateMessage *)forwardedMessage
                              andThen:(void (^)(NSError *error))callback;

// List post icons usable for a new thread in a forum.
//
// forumID  - Which forum to list icons for.
// callback - A block to call after listing post icons, which takes as parameters:
//              error - An error on failure, or nil on success.
//              form  - An AwfulForm object with thread tags and secondary thread tags on success, or nil on failure.
//
// Returns the enqueued network operation.
- (NSOperation *)listAvailablePostIconsForForumWithID:(NSString *)forumID
                                              andThen:(void (^)(NSError *error, AwfulForm *form))callback;

/**
 * @param threadTag           Can be nil.
 * @param secondaryTag        Can be nil.
 * @param secondaryTagFormKey The key passed in to the callback block of -listAvailablePostIconsForForumWithID...
 * @param callback            A block to call after posting the thread, which takes as parameters: an NSError object on failure or nil on success; and the new AwfulThread object on success, or nil on failure.
 *
 * @return An enqueued network operation.
 */
- (NSOperation *)postThreadInForum:(AwfulForum *)forum
                       withSubject:(NSString *)subject
                         threadTag:(AwfulThreadTag *)threadTag
                      secondaryTag:(AwfulThreadTag *)secondaryTag
               secondaryTagFormKey:(NSString *)secondaryTagFormKey
                            BBcode:(NSString *)text
                           andThen:(void (^)(NSError *error, AwfulThread *thread))callback;

@end
