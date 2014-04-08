//  AwfulThreadTableViewController.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIViewController+AwfulTheme.h"
#import "AwfulFetchedResultsControllerDataSource.h"
#import "AwfulModels.h"
#import "AwfulPostsViewController.h"
#import "AwfulThreadCell.h"

/**
 * An AwfulThreadTableViewController shows a list of threads.
 *
 * Subclasses may want to implement -configureCell:withObject: (from AwfulFetchedResultsControllerDataSourceDelegate) for more specific customization of the AwfulThreadCell objects.
 */
@interface AwfulThreadTableViewController : AwfulTableViewController <AwfulFetchedResultsControllerDataSourceDelegate>

/**
 * The data source that provides the threads. Set its fetched results controller if you want data!
 */
@property (readonly, strong, nonatomic) AwfulFetchedResultsControllerDataSource *threadDataSource;

/**
 * Pushes a posts view controller on to the navigation stack or shows it in the expanding split view, as appropriate.
 */
- (void)showPostsViewController:(AwfulPostsViewController *)postsViewController;

@end
