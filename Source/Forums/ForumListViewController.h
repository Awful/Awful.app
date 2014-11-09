//  ForumListViewController.h
//
//  Copyright 2010 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIViewController+AwfulTheme.h"
@class Forum;

@interface ForumListViewController : AwfulTableViewController

// Designated initializer.
- (instancetype)initWithManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;

- (void)showForum:(Forum *)forum animated:(BOOL)animated;

@end
