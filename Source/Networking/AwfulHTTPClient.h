//  AwfulHTTPClient.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <AFNetworking/AFNetworking.h>
#import "AwfulThreadPage.h"
@class AwfulPrivateMessage;
@class AwfulUser;

@interface AwfulHTTPClient : AFHTTPClient

// Singleton instance.
+ (AwfulHTTPClient *)client;

// Clear singleton instance.
+ (void)reset;

// Returns YES if the forums are reachable through current network settings.
@property (readonly, getter=isReachable, nonatomic) BOOL reachable;

// Returns YES if someone is currently logged in to the SA Forums.
@property (readonly, getter=isLoggedIn, nonatomic) BOOL loggedIn;

// Gets the threads in a forum on a given page.
//
// forumID  - The ID of the forum with the threads.
// page     - Which page to get.
// callback - A block to call after listing the threads, which takes as parameters:
//              error   - An error on failure, or nil on success.
//              threads - A list of AwfulThread on success, or nil on failure.
//
// Returns the enqueued network operation.
- (NSOperation *)listThreadsInForumWithID:(NSString *)forumID
                                threadTag:(NSString*)tag
                                   onPage:(NSInteger)page
                                  andThen:(void (^)(NSError *error, NSArray *threads))callback;

// Gets the bookmarked threads on a given page.
//
// page     - Which page to get.
// callback - A block to call after listing the threads, which takes as parameters:
//              error   - An error on failure, or nil on success.
//              threads - A list of AwfulThread on success, or nil on failure.
//
// Returns the enqueued network operation.
- (NSOperation *)listBookmarkedThreadsOnPage:(NSInteger)page
                                     andThen:(void (^)(NSError *error, NSArray *threads))callback;

// Gets the posts in a thread, optionally restricted to a single author.
//
// threadID     - Which thread to list.
// page         - Which page to get. First page is 1; AwfulPageNextUnread and AwfulPageLast are
//                also available.
// singleUserID - An author's user ID to filter the thread. If nil, get posts from all authors.
// callback - A block to call after listing the posts, which takes as parameters:
//              error             - An error on failure, or nil on success.
//              posts             - The posts gleaned from the page.
//              firstUnreadPost   - Which post in the posts array is the first unread.
//                                  Only set if the page requested was AwfulPageNextUnread.
//              advertisementHTML - The ad at the bottom of the page.
//
// N.B. If you've never read a thread before (or marked it unread), the "next unread" page is the
//      last page of the thread. (It's an SA thing, I don't get it either.)
//
// Returns the enqueued network operation.
- (NSOperation *)listPostsInThreadWithID:(NSString *)threadID
                                  onPage:(AwfulThreadPage)page
                            singleUserID:(NSString *)singleUserID
                                 andThen:(void (^)(NSError *error,
                                                   NSArray *posts,
                                                   NSUInteger firstUnreadPost,
                                                   NSString *advertisementHTML))callback;

// Get the logged-in user's name and ID.
//
// callback - A block to call after getting the user's info, which takes as parameters:
//              error    - An error on failure, or nil on success.
//              userInfo - A dictionary with keys "userID", "username" on success, or nil on
//                         failure.
//
// Returns the enqueued network operation.
- (NSOperation *)learnUserInfoAndThen:(void (^)(NSError *error, NSDictionary *userInfo))callback;

// Add or remove a bookmark for a thread.
//
// threadID     - The ID of the thread to add.
// isBookmarked - YES if a bookmark should be added for the thread, or NO if it should be removed.
// callback     - A block to call after removing the thread, which takes as parameters:
//                  error - An error on failure, or nil on success.
//
// Returns the enqueued network operation.
- (NSOperation *)setThreadWithID:(NSString *)threadID
                    isBookmarked:(BOOL)isBookmarked
                         andThen:(void (^)(NSError *error))callback;

// Get the forum hierarchy.
//
// callback - A block to call after updating all forums and subforums, which takes as parameters:
//              error  - An error on failure, or nil on succes.
//              forums - A list of AwfulForum on success, or nil on failure.
//
// Returns the enqueued network operation.
- (NSOperation *)listForumsAndThen:(void (^)(NSError *error, NSArray *forums))callback;

// Posts a new reply to a thread.
//
// threadID - The ID of the thread to reply to.
// text     - The bbcode-formatted reply.
// callback - A block to call after sending the reply, which takes as parameters:
//              error  - An error on failure, or nil on success.
//              postID - The ID of the new post, or nil if it's the last post in the thread.
//
// Returns the enqueued network operation.
- (NSOperation *)replyToThreadWithID:(NSString *)threadID
                                text:(NSString *)text
                             andThen:(void (^)(NSError *error, NSString *postID))callback;

// Get the text of a post, for editing.
//
// postID   - The ID of the post.
// callback - A block to call after getting the text of the post, which takes as parameters:
//              error - An error on failure, or nil on success.
//              text  - The text content of the post, or nil on failure.
//
// Returns the enqueued network operation.
- (NSOperation *)getTextOfPostWithID:(NSString *)postID
                             andThen:(void (^)(NSError *error, NSString *text))callback;

// Get the text of a post, for quoting.
//
// postID - The ID of the post.
// callback - A block to call after getting the quoted text of the post, which takes as parameters:
//              error      - An error on failure, or nil on success.
//              quotedText - The quoted text content of the post, or nil on failure.
//
// Returns the enqueued network operation.
- (NSOperation *)quoteTextOfPostWithID:(NSString *)postID
                               andThen:(void (^)(NSError *error, NSString *quotedText))callback;

// Edit a post's content.
//
// postID - The post to edit.
// text   - The new content for the post.
// callback - A block to call after editing the post, which takes as parameters:
//              error - An error on failure, or nil on success.
//
// Returns the enqueued network operation.
- (NSOperation *)editPostWithID:(NSString *)postID
                           text:(NSString *)text
                        andThen:(void (^)(NSError *error))callback;

// Rate a thread.
//
// threadID - Which thread to rate.
// rating   - A rating from 1 to 5, inclusive.
// callback - A block to call after voting, which takes as parameters:
//              error - An error on failure, or nil on success.
//
// Returns the enqueued network operation.
- (NSOperation *)rateThreadWithID:(NSString *)threadID
                           rating:(NSInteger)rating
                          andThen:(void (^)(NSError *error))callback;

// Mark a thread as read up to a point.
//
// threadID - Which thread to mark.
// index    - How many posts to mark as read.
// callback - A block to call after marking, which takes as parameters:
//              error - An error on failure, or nil on success.
//
// Returns the enqueued network operation.
- (NSOperation *)markThreadWithID:(NSString *)threadID
              readUpToPostAtIndex:(NSString *)index
                          andThen:(void (^)(NSError *error))callback;

// Mark an entire thread as unread.
//
// threadID - Which thread to mark.
// callback - A block to call after marking, which takes as parameters:
//              error - An error on failure, or nil on success.
//
// Returns the enqueued network operation.
- (NSOperation *)forgetReadPostsInThreadWithID:(NSString *)threadID
                                       andThen:(void (^)(NSError *error))callback;

// Logs in to the Forums, setting a cookie for future requests.
//
// username - Who to log in as.
// password - Their password.
// callback - A block to call after logging in, which takes as parameters:
//              error    - An error on failure, or nil on success.
//              userInfo - A dictionary with keys "userID" and "username" on success, or nil on
//                         failure.
//
// Returns the enqueued network operation.
- (NSOperation *)logInAsUsername:(NSString *)username
                    withPassword:(NSString *)password
                         andThen:(void (^)(NSError *error, NSDictionary *userInfo))callback;

// Sent when someone logs in.
extern NSString * const AwfulUserDidLogInNotification;

// Finds the thread and page where a post appears.
//
// postID   - The ID of the post to locate.
// callback - A block to call after locating the post, which takes as parameters:
//              error    - An error on failure, or nil on success.
//              threadID - The ID of the thread containing the post, or nil on failure.
//              page     - The page number where the post appears, or NSIntegerMax if the post
//                         appears on the last page, or 0 on failure.
//
// Returns the enqueued network operation.
- (NSOperation *)locatePostWithID:(NSString *)postID
    andThen:(void (^)(NSError *error, NSString *threadID, AwfulThreadPage page))callback;

// Find a user's profile.
//
// userID   - The ID of the user to update with their profile info.
// callback - A block to call after updating the user info, which takes as parameters:
//              error - An error on failure, or nil on success.
//              user  - The updated user on success, or nil on failure.
//
// Returns the enqueued network operation.
- (NSOperation *)profileUserWithID:(NSString *)userID
                           andThen:(void (^)(NSError *error, AwfulUser *user))callback;

// List probations, bans, and permabans from the Leper's Colony.
//
// page     - Which page of the Leper's Colony to list. First page is page 1.
// callback - A block to call after listing punishment, which takes as parameters:
//              error - An error on failure, or nil on success.
//              bans  - An array of BanParsedInfo instances on success, or nil on failure.
//
// Returns the enqueued network operation.
- (NSOperation *)listBansOnPage:(NSInteger)page
                        forUser:(NSString *)userID
                        andThen:(void (^)(NSError *error, NSArray *bans))callback;

// List private messages in the logged-in user's Inbox.
//
// callback - A block to call after listing messages, which takes as parameters:
//              error    - An error on failure, or nil on success.
//              messages - An array of PrivateMessageParsedInfo instances on success, or nil on
//                         failure.
//
// Returns the enqueued network operation.
- (NSOperation *)listPrivateMessagesAndThen:(void (^)(NSError *error, NSArray *messages))callback;

// Delete a private message.
//
// messageID - The ID of the message to delete.
// callback  - A block to call after deleting the message, which takes as parameters:
//               error - An error on failure, or nil on success.
//
// Returns the enqueued network operation.
- (NSOperation *)deletePrivateMessageWithID:(NSString *)messageID
                                    andThen:(void (^)(NSError *error))callback;

// Read a private message.
//
// messageID - The ID of the message to read.
// callback  - A block to call after reading the message, which takes as parameters:
//               error   - An error on failure, or nil on success.
//               message - The message on success, or nil on failure.
//
// Returns the enqueued network operation.
- (NSOperation *)readPrivateMessageWithID:(NSString *)messageID
                                  andThen:(void (^)(NSError *error,
                                                    AwfulPrivateMessage *message))callback;

// Quote a private message.
//
// messageID - The ID of the message to quote.
// callback  - A block to call after quoting the message, which takes as parameters:
//               error  - An error on failure, or nil on success.
//               bbcode - The quoted message on success, or nil on failure.
//
// Returns the enqueued network operation.
- (NSOperation *)quotePrivateMessageWithID:(NSString *)messageID
                                   andThen:(void (^)(NSError *error, NSString *bbcode))callback;

// List post icons usable for private messages.
//
// callback - A block to call after listing post icons, which takes as parameters:
//              error     - An error on failure, or nil on success.
//              postIcons - An array of AwfulThreadTag instances on success, or nil on failure.
//
// Returns the enqueued network operation.
- (NSOperation *)listAvailablePrivateMessagePostIconsAndThen:(void (^)(NSError *error,
                                                                       NSArray *postIcons))callback;

// Send a private message.
//
// username         - The user who will receive the message.
// subject          - The subject of the message.
// iconID           - The ID of the post icon to use, or nil for no icon.
// text             - The BBCode text of the message.
// replyMessageID   - The message ID of the message this is regarding, or nil if not a reply.
// forwardMessageID - The message ID of the message this is a forward of, or nil of not a forward.
// callback         - A block to call after sending the message, which takes as parameters:
//                      error - An error on failure, or nil on success.
//
// Returns the enqueued network operation.
- (NSOperation *)sendPrivateMessageTo:(NSString *)username
                              subject:(NSString *)subject
                                 icon:(NSString *)iconID
                                 text:(NSString *)text
               asReplyToMessageWithID:(NSString *)replyMessageID
           forwardedFromMessageWithID:(NSString *)forwardMessageID
                              andThen:(void (^)(NSError *error))callback;

// List post icons usable for a new thread in a forum.
//
// forumID  - Which forum to list icons for.
// callback - A block to call after listing post icons, which takes as parameters:
//              error              - An error on failure, or nil on success.
//              postIcons          - An array of AwfulThreadTag instances on success, or nil on
//                                   failure.
//              secondaryPostIcons - An array of AwfulThreadTag instances on success, or nil if
//                                   the forum doesn't use secondary thread tags, or nil on failure.
//              secondaryIconKey   - Pass this to -postThreadInForumWithID... along with the ID of
//                                   the selected secondary icon.
//
// Returns the enqueued network operation.
- (NSOperation *)listAvailablePostIconsForForumWithID:(NSString *)forumID
                                              andThen:(void (^)(NSError *error,
                                                                NSArray *postIcons,
                                                                NSArray *secondaryPostIcons,
                                                                NSString *secondaryIconKey
                                                                ))callback;

// Post a new thread in a forum.
//
// forumID          - Which forum to post in. Cannot be nil.
// subject          - What the thread is about. Cannot be nil.
// iconID           - The ID of the post icon to use, or nil for the default icon.
// secondaryIconID  - The ID of the secondary post icon to use, or nil if no icon is required.
// secondaryIconKey - The key passed in to the callback block of
//                    -listAvailablePostIconsForForumWithID..., or nil if no icon is required.
// text             - The contents of the original post. Cannot be nil.
// callback         - A block to call after posting the thread, which takes as parameters:
//                      error    - An error on failure, or nil on success.
//                      threadID - The ID of the newly-created thread on success, or nil on failure.
//
// Returns the enqueued network operation.
- (NSOperation *)postThreadInForumWithID:(NSString *)forumID
                                 subject:(NSString *)subject
                                    icon:(NSString *)iconID
                           secondaryIcon:(NSString *)secondaryIconID
                        secondaryIconKey:(NSString *)secondaryIconKey
                                    text:(NSString *)text
                                 andThen:(void (^)(NSError *error, NSString *threadID))callback;

@end
