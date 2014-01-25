//  AwfulPostsViewController.h
//
//  Copyright 2010 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIViewController+AwfulTheme.h"
#import "AwfulModels.h"

/**
 * An AwfulPostsViewController shows a list of posts in a thread.
 */
@interface AwfulPostsViewController : AwfulViewController

/**
 * Returns an initialized AwfulPostsViewController. This is the designated initializer.
 *
 * @param thread The thread whose posts are shown.
 * @param author An optional author used to filter the shown posts. May be nil.
 */
- (id)initWithThread:(AwfulThread *)thread author:(AwfulUser *)author;

/**
 * Returns an initialized AwfulPostsViewController.
 *
 * @param thread The thread whose posts are shown.
 */
- (id)initWithThread:(AwfulThread *)thread;

/**
 * Set the currently-visible post.
 */
- (void)setTopPost:(AwfulPost*)topPost;

/**
 * The thread whose posts are shown.
 */
@property (readonly, strong, nonatomic) AwfulThread *thread;

/**
 * Only the author's posts are shown. If nil, all posts are shown.
 */
@property (readonly, strong, nonatomic) AwfulUser *author;

/**
 * The currently-visible (or currently-loading) page of posts.
 */
@property (assign, nonatomic) AwfulThreadPage page;

/**
 * An array of AwfulPost objects of the currently-visible posts.
 */
@property (readonly, copy, nonatomic) NSArray *posts;

@end
