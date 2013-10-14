//  AwfulForumsListController.h
//
//  Copyright 2010 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIViewController+AwfulTheme.h"
#import "AwfulModels.h"

@interface AwfulForumsListController : AwfulTableViewController

// Designated initializer.
- (id)initWithManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;

- (void)showForum:(AwfulForum *)forum animated:(BOOL)animated;

@end
