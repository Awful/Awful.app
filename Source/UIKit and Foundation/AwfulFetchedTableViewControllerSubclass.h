//
//  AwfulFetchedTableViewControllerSubclass.h
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

@interface AwfulFetchedTableViewController ()

@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;

@property (nonatomic) BOOL userDrivenChange;

@property (nonatomic) BOOL ignoreUpdates;

@end
