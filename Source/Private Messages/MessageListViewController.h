//  MessageListViewController.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIViewController+AwfulTheme.h"

/**
 * A MessageListViewController shows a list of private messages.
 */
@interface MessageListViewController : AwfulTableViewController

/**
 * @param managedObjectContext A managed object context from which to load the private messages.
 */
- (instancetype)initWithManagedObjectContext:(NSManagedObjectContext *)managedObjectContext NS_DESIGNATED_INITIALIZER;

/**
 * The managed object context prividing the private messages.
 */
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;

@end
