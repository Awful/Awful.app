//
//  AwfulFetchedTableViewController.h
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import "AwfulTableViewController.h"

@interface AwfulFetchedTableViewController : AwfulTableViewController <NSFetchedResultsControllerDelegate>

// Subclasses must implement.
- (NSFetchedResultsController *)createFetchedResultsController;

@end
