//  AwfulPost.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulModels.h"

/**
 * An AwfulPost object is a single reply to a thread.
 */
@interface AwfulPost : AwfulManagedObject

/**
 * The post's attached image ID.
 */
@property (copy, nonatomic) NSString *attachmentID;

/**
 * YES if the post is editable by the currently logged-in user.
 */
@property (assign, nonatomic) BOOL editable;

/**
 * The most recent date on which the post was edited.
 */
@property (strong, nonatomic) NSDate *editDate;

/**
 * The raw HTML contents of the post.
 */
@property (copy, nonatomic) NSString *innerHTML;

/**
 * When the post was written.
 */
@property (strong, nonatomic) NSDate *postDate;

/**
 * The presumably unique ID of the post.
 */
@property (copy, nonatomic) NSString *postID;

/**
 * Where in the thread the post is found when showing only posts by the author, starting at 1.
 */
@property (assign, nonatomic) int32_t singleUserIndex;

/**
 * Where in the thread the post is found, starting at 1.
 */
@property (assign, nonatomic) int32_t threadIndex;

/**
 * The author of the post.
 */
@property (strong, nonatomic) AwfulUser *author;

/**
 * The most recent editor of the post. May be nil even if the post was edited.
 */
@property (strong, nonatomic) AwfulUser *editor;

/**
 * The post's thread.
 */
@property (strong, nonatomic) AwfulThread *thread;

/**
 * YES if the currently logged-in user has seen this post, or NO otherwise.
 */
@property (readonly, nonatomic) BOOL beenSeen;

/**
 * Which page of the thread on which this post is found, if pages have at most 40 posts. Returns 0 if the page is unknown.
 */
@property (readonly, nonatomic) NSInteger page;

/**
 * Which page of the thread on which this post is found when showing only posts by the author, if pages have at most 40 posts. Returns 0 if the page is unknown.
 */
@property (readonly, nonatomic) NSInteger singleUserPage;

/**
 * Returns an AwfulPost object with the post ID, inserting one if necessary.
 */
+ (instancetype)firstOrNewPostWithPostID:(NSString *)postID
                  inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

@end
