//  BookmarkedThreadListViewController.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AbstractThreadListViewController.h"

/**
 * A BookmarkedThreadListViewController shows a list of bookmarked threads.
 */
@interface BookmarkedThreadListViewController : AbstractThreadListViewController

/**
 * @param managedObjectContext The managed object context from which to fetch bookmarked threads.
 */
- (instancetype)initWithManagedObjectContext:(NSManagedObjectContext *)managedObjectContext NS_DESIGNATED_INITIALIZER;

/**
 * The managed object context sourcing the bookmarked threads.
 */
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;

@end
