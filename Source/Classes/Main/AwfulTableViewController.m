//
//  AwfulTableViewController.m
//  Awful
//
//  Created by Sean Berry on 2/29/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulTableViewController.h"

@implementation AwfulTableViewController

@synthesize networkOperation = _networkOperation;
@synthesize reloading = _reloading;

#pragma mark - View Cycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    if ([self canPullToRefresh]) {
        // TODO
    }
    self.reloading = NO;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.networkOperation cancel];
    [self finishedRefreshing];
}

#pragma mark - Refresh

- (void)refresh
{
    self.reloading = YES;
}

-(void)stop
{
    
}

- (void)finishedRefreshing
{
    self.reloading = NO;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return YES;
    }
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (BOOL)canPullToRefresh
{
    return YES;
}

-(BOOL) isOnLastPage {
    return NO;
}

#pragma mark cells

- (void)configureCell:(UITableViewCell*)cell atIndexPath:(NSIndexPath *)indexPath {  
    //subclass must override
    abort();  
    
    //NSManagedObject *obj = (AwfulManagedObject*)[_fetchedResultsController objectAtIndexPath:indexPath];
    //[obj setContentForCell:cell];
}

@end
