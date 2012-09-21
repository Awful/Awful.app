//
//  AwfulTableViewController.m
//  Awful
//
//  Created by Sean Berry on 2/29/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulTableViewController.h"
#import "SVPullToRefresh.h"

@implementation AwfulTableViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    if ([self canPullToRefresh]) {
        __weak AwfulTableViewController *blockSelf = self;
        [self.tableView addPullToRefreshWithActionHandler:^{
            [blockSelf refresh];
        }];
    }
    self.reloading = NO;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.networkOperation cancel];
    [self finishedRefreshing];
}

- (void)refresh
{
    self.reloading = YES;
}

- (void)stop
{
    [self.tableView.pullToRefreshView stopAnimating];
}

- (void)finishedRefreshing
{
    self.reloading = NO;
    [self.tableView.pullToRefreshView stopAnimating];
}

- (BOOL)canPullToRefresh
{
    return YES;
}

- (BOOL)isOnLastPage
{
    return NO;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return YES;
    }
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (void)configureCell:(UITableViewCell*)cell atIndexPath:(NSIndexPath *)indexPath
{
    [NSException raise:@"SubclassMustImplement"
                format:@"Subclasses must implement %@", NSStringFromSelector(_cmd)];
}

@end
