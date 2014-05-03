//  AwfulForum.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulModels.h"

/**
 * An AwfulForum is a collection of threads somewhere in a hierarchy of forums and categories.
 */
@interface AwfulForum : AwfulManagedObject

/**
 * The parameter in a URL like `http://forums.somethingawful.com/forumdisplay.php?forumid=202`.
 */
@property (copy, nonatomic) NSString *forumID;

@property (assign, nonatomic) BOOL canPost;

/**
 * The position of the forum when displayed in the big list of forums (`http://forums.somethingawful.com`) or in its parent forum, starting at 0.
 */
@property (assign, nonatomic) int32_t index;

/**
 * A property that should be deleted.
 */
@property (strong, nonatomic) NSDate *lastRefresh;

/**
 * Ditto.
 */
@property (strong, nonatomic) NSDate *lastFilteredRefresh;

/**
 * The name of the forum shown in the big list of forums or in its parent forum.
 */
@property (copy, nonatomic) NSString *name;

/**
 * The forum's category.
 */
@property (strong, nonatomic) AwfulCategory *category;

/**
 * A set of AwfulForum objects representing the forum's subforums.
 */
@property (copy, nonatomic) NSOrderedSet *children;

/**
 * The forum's parent. Can be nil.
 */
@property (strong, nonatomic) AwfulForum *parentForum;

/**
 * A set of AwfulThread objects representing the forum's threads.
 */
@property (strong, nonatomic) NSSet *threads;

/**
 * A set of AwfulThreadTag objects that may be used by the forum's threads.
 */
@property (copy, nonatomic) NSOrderedSet *threadTags;

/**
 * A set of AwfulThreadTag objects that may be used as a secondary tag by the forum's threads.
 */
@property (copy, nonatomic) NSOrderedSet *secondaryThreadTags;

/**
 * Returns an AwfulForum with the given forum ID, inserting one if necessary.
 */
+ (instancetype)fetchOrInsertForumInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
                                                  withID:(NSString *)forumID;

@end
