//  ThreadListViewController.h
//
//  Copyright 2010 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AbstractThreadListViewController.h"
@class Forum;

/**
 * A ThreadListViewController displays a list of threads in a forum.
 */
@interface ThreadListViewController : AbstractThreadListViewController

/**
 * Returns an initialized AwfulForumThreadTableViewController. This is the designated initializer.
 *
 * @param forum An Forum whose threads are shown.
 */
- (instancetype)initWithForum:(Forum *)forum;

/**
 * The forum whose threads are shown.
 */
@property (readonly, strong, nonatomic) Forum *forum;

@end
