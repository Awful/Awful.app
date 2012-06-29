//
//  AwfulTableViewController.m
//  Awful
//
//  Created by Sean Berry on 2/29/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulTableViewController.h"
#import "AwfulSettings.h"
#import "AwfulRefreshControl.h"
#import "AwfulLoadNextControl.h"

@interface AwfulTableViewController ()

@property (nonatomic,strong) AwfulLoadNextControl* loadNextControl;

@end

@implementation AwfulTableViewController

@synthesize networkOperation = _networkOperation;
//@synthesize refreshHeaderView = _refreshHeaderView;
@synthesize refreshControl = __refreshControl;
@synthesize reloading = _reloading;
@synthesize loadNextControl = _loadNextControl;

#pragma mark - View Cycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    if ([self canPullToRefresh]) {
        self.refreshControl = [[AwfulRefreshControl alloc] initWithFrame:CGRectMake(0, -50, self.tableView.fsW, 50)];
        self.refreshControl.loadedDate = [NSDate date];
        [self.refreshControl addTarget:self action:@selector(refreshControlChanged:) forControlEvents:(UIControlEventValueChanged)];
        [self.refreshControl addTarget:self action:@selector(refreshControlCancel:) forControlEvents:(UIControlEventTouchCancel)];
        [self.tableView addSubview:self.refreshControl];
        
        
        
        self.loadNextControl = [[AwfulLoadNextControl alloc] initWithFrame:CGRectMake(0, self.tableView.contentSize.height, self.tableView.fsW, 50)];
        [self.loadNextControl addTarget:self
                                 action:@selector(loadNextControlChanged:) 
                       forControlEvents:(UIControlEventValueChanged)];
        [self.loadNextControl addTarget:self 
                                 action:@selector(refreshControlCancel:) 
                       forControlEvents:(UIControlEventTouchCancel)];
        [self.tableView addSubview:self.loadNextControl];
    }
    self.reloading = NO;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.networkOperation cancel];
    [self finishedRefreshing];
}

#pragma mark - UIScrollViewDelegate Methods
-(void) scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    if (self.refreshControl) {
        self.refreshControl.userScrolling = YES;
    }
    
    if (self.loadNextControl)
        self.loadNextControl.userScrolling = YES;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{	
    if (self.refreshControl && self.refreshControl.userScrolling) {
        [self.refreshControl didScrollInScrollView:scrollView];
    }
    
    if (self.loadNextControl && self.loadNextControl.userScrolling)
        [self.loadNextControl didScrollInScrollView:scrollView];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (self.refreshControl) {
        self.refreshControl.userScrolling = NO;
    }
    
    if (self.loadNextControl)
        self.loadNextControl.userScrolling = NO;
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
	//[self.refreshHeaderView egoRefreshScrollViewDataSourceDidFinishedLoading:self.tableView];
    self.refreshControl.loadedDate = [NSDate date];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
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

-(void) refreshControlChanged:(AwfulRefreshControl*)refreshControl {
    if (refreshControl.state == AwfulRefreshControlStateLoading)
        [self refresh];
}

-(void) loadNextControlChanged:(AwfulRefreshControl*)refreshControl {

}

-(void) refreshControlCancel:(AwfulRefreshControl*)refreshControl {
    [self stop];
}

@end
