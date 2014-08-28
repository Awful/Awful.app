//  AbstractThreadListViewController.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIViewController+AwfulTheme.h"
#import "AwfulFetchedResultsControllerDataSource.h"
#import "AwfulModels.h"
#import "AwfulThreadCell.h"

/**
 * An AbstractThreadListViewController shows a list of threads.
 *
 * Subclasses may want to implement -configureCell:withObject: (from AwfulFetchedResultsControllerDataSourceDelegate) for more specific customization of the AwfulThreadCell objects.
 */
@interface AbstractThreadListViewController : AwfulTableViewController <AwfulFetchedResultsControllerDataSourceDelegate>

/**
 * The data source that provides the threads. Set its fetched results controller if you want data!
 */
@property (readonly, strong, nonatomic) AwfulFetchedResultsControllerDataSource *threadDataSource;

@end
