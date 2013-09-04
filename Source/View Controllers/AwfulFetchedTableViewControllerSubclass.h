//  AwfulFetchedTableViewControllerSubclass.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulFetchedTableViewController.h"

@interface AwfulFetchedTableViewController ()

@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;

@property (nonatomic) BOOL userDrivenChange;

@property (nonatomic) BOOL ignoreUpdates;

@end
