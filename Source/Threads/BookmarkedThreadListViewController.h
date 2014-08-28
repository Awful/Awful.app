//  BookmarkedThreadListViewController.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AbstractThreadListViewController.h"

/**
 * A BookmarkedThreadListViewController shows a list of bookmarked threads.
 */
@interface BookmarkedThreadListViewController : AbstractThreadListViewController

/**
 * Returns an initialized AwfulBookmarkedThreadTableViewController. This is the designated initializer.
 *
 * @param managedObjectContext The managed object context from which to fetch bookmarked threads.
 */
- (id)initWithManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

/**
 * The managed object context sourcing the bookmarked threads.
 */
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;

@end
