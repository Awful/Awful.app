//  AwfulJumpToPageController.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulSemiModalViewController.h"
#import "AwfulPostsViewController.h"
#import "AwfulThreadPage.h"

/**
 * A page picker shortcuts for first page and last page.
 */
@interface AwfulJumpToPageController : AwfulSemiModalViewController

/**
 * Returns an initialized AwfulJumpToPageController. This is the designated initializer.
 */
- (id)initWithPostsViewController:(AwfulPostsViewController *)postsViewController;

@property (readonly, strong, nonatomic) AwfulPostsViewController *postsViewController;

@end
