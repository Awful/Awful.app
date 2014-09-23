//  ForumListViewController.h
//
//  Copyright 2010 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIViewController+AwfulTheme.h"
#import "AwfulDataStack.h"
#import "AwfulModels.h"

/**
 A ForumListViewController lists the hierarchy of all forums, allowing subforums to collapse.
 */
@interface ForumListViewController : AwfulTableViewController

- (instancetype)initWithDataStack:(AwfulDataStack *)dataStack NS_DESIGNATED_INITIALIZER;

@property (readonly, strong, nonatomic) AwfulDataStack *dataStack;

/**
 * Opens a listed forum.
 */
- (void)showForum:(AwfulForum *)forum animated:(BOOL)animated;

@end
