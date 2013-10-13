//  AwfulForumThreadTableViewController.h
//
//  Copyright 2010 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIViewController+AwfulTheme.h"
#import "AwfulModels.h"

/**
 * An AwfulForumThreadTableViewController displays a list of threads in a forum.
 */
@interface AwfulForumThreadTableViewController : AwfulTableViewController

/**
 * Returns an initialized AwfulForumThreadTableViewController. This is the designated initializer.
 *
 * @param forum An AwfulForum whose threads are shown.
 */
- (id)initWithForum:(AwfulForum *)forum;

/**
 * The forum whose threads are shown.
 */
@property (readonly, strong, nonatomic) AwfulForum *forum;

@end
