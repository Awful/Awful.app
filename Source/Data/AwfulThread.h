//  AwfulThread.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulModels.h"

typedef NS_ENUM(int16_t, AwfulStarCategory) {
    AwfulStarCategoryOrange = 0,
    AwfulStarCategoryRed,
    AwfulStarCategoryYellow,
    AwfulStarCategoryNone
};

/**
 * An AwfulThread object is a collection of posts that appears in a forum.
 */
@interface AwfulThread : AwfulManagedObject

/**
 * YES if the thread appears in the archives, otherwise NO.
 */
@property (assign, nonatomic) BOOL archived;

/**
 * A property that should be deleted.
 */
@property (assign, nonatomic) BOOL hideFromList;

/**
 * YES if the currently logged-in user has bookmarked the thread, otherwise NO.
 */
@property (assign, nonatomic) BOOL isBookmarked;

/**
 * YES if the thread is closed (does not accept new posts), otherwise NO.
 */
@property (assign, nonatomic) BOOL isClosed;

/**
 * YES if the thread is stuck to the top of the forum, otherwise NO.
 */
@property (assign, nonatomic) BOOL isSticky;

/**
 * A property that should be deleted.
 */
@property (copy, nonatomic) NSString *lastPostAuthorName;

/**
 * The date that the most recent post was written in the thread.
 */
@property (strong, nonatomic) NSDate *lastPostDate;

/**
 * The number of pages in the thread.
 */
@property (assign, nonatomic) int32_t numberOfPages;

/**
 * The number of posts that the currently logged-in user has seen in the thread, including the OP.
 */
@property (assign, nonatomic) int32_t seenPosts;

/**
 * The color assigned to the thread in the currently logged-in user's bookmarks.
 */
@property (assign, nonatomic) AwfulStarCategory starCategory;

/**
 * Where the thread appears atop the forum, among the stickied threads, ending at -1.
 */
@property (assign, nonatomic) int32_t stickyIndex;

/**
 * The URL of the thread's main icon.
 */
@property (strong, nonatomic) NSURL *threadIconImageURL;

/**
 * The URL of the thread's secondary icon.
 */
@property (strong, nonatomic) NSURL *threadIconImageURL2;

/**
 * The presumably unique ID of the thread.
 */
@property (copy, nonatomic) NSString *threadID;

/**
 * The thread's rating, between 0 and 5 (inclusive).
 */
@property (strong, nonatomic) NSDecimalNumber *threadRating;

/**
 * The number of votes that make up the thread's rating.
 */
@property (assign, nonatomic) int16_t threadVotes;

/**
 * The thread's title.
 */
@property (copy, nonatomic) NSString *title;

/**
 * The number of replies to the thread, excluding the OP.
 */
@property (assign, nonatomic) int32_t totalReplies;

/**
 * Who posted the thread.
 */
@property (strong, nonatomic) AwfulUser *author;

/**
 * Which forum the thread was posted in.
 */
@property (strong, nonatomic) AwfulForum *forum;

/**
 * A set of AwfulPost objects in this thread.
 */
@property (copy, nonatomic) NSSet *posts;

/**
 * A set of AwfulSingleUserThreadInfo objects for this thread.
 */
@property (copy, nonatomic) NSSet *singleUserThreadInfos;

/**
 * The name of the thread's main icon, as determined from threadIconImageURL.
 */
@property (readonly, nonatomic) NSString *firstIconName;

/**
 * The name of the thread's secondary icon, as determined from threadIconImageURL2. May be nil.
 */
@property (readonly, nonatomic) NSString *secondIconName;

/**
 * YES if the currently logged-in user has seen any posts in this thread, otherwise NO.
 */
@property (readonly, nonatomic) BOOL beenSeen;

/**
 * Returns an array of AwfulThread objects derived from an array of ThreadParsedInfo objects.
 */
+ (NSArray *)threadsCreatedOrUpdatedWithParsedInfo:(NSArray *)threadInfos
                            inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

/**
 * Returns an AwfulThread object with the given thread ID, inserting one if necessary.
 */
+ (instancetype)firstOrNewThreadWithThreadID:(NSString *)threadID
                      inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

/**
 * Returns the number of pages of posts that the user has made in the thread, or 0 if unknown.
 */
- (NSInteger)numberOfPagesForSingleUser:(AwfulUser *)singleUser;

/**
 * Sets the number of pages of posts that the user has made in the thread.
 */
- (void)setNumberOfPages:(NSInteger)numberOfPages forSingleUser:(AwfulUser *)singleUser;

@end
