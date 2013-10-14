//  AwfulPrivateMessageTableViewController.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIViewController+AwfulTheme.h"

/**
 * An AwfulPrivateMessageTableViewController shows a list of private messages.
 */
@interface AwfulPrivateMessageTableViewController : AwfulTableViewController

/**
 * Returns an initialized AwfulPrivateMessageTableViewController. This is the designated initializer.
 *
 * @param managedObjectContext A managed object context from which to load the private messages.
 */
- (id)initWithManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

/**
 * The managed object context prividing the private messages.
 */
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;

@end
