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
@synthesize awfulRefreshControl = _awfulRefreshControl;
@synthesize reloading = _reloading;
@synthesize loadNextControl = _loadNextControl;

#pragma mark - View Cycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    if ([self canPullToRefresh]) {
        self.awfulRefreshControl.loadedDate = [NSDate date];
        
        _awfulRefreshControl.loadedDate = [NSDate date];
        [_awfulRefreshControl addTarget:self action:@selector(refreshControlChanged:) forControlEvents:(UIControlEventValueChanged)];
        [_awfulRefreshControl addTarget:self action:@selector(refreshControlCancel:) forControlEvents:(UIControlEventTouchCancel)];
        [self.tableView addSubview:self.awfulRefreshControl];
        
        
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

-(AwfulRefreshControl*) awfulRefreshControl {
    if (!_awfulRefreshControl) {
        _awfulRefreshControl = [[AwfulRefreshControl alloc] initWithFrame:CGRectMake(0, -50, self.tableView.fsW, 50)];
    }
return _awfulRefreshControl;
}

#pragma mark - UIScrollViewDelegate Methods
-(void) scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    if (self.awfulRefreshControl) {
        self.awfulRefreshControl.userScrolling = YES;
    }
    
    if (self.loadNextControl)
        self.loadNextControl.userScrolling = YES;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{	
    if (self.awfulRefreshControl && self.awfulRefreshControl.userScrolling) {
        [self.awfulRefreshControl didScrollInScrollView:scrollView];
    }
    
    if (self.loadNextControl && self.loadNextControl.userScrolling)
        [self.loadNextControl didScrollInScrollView:scrollView];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (self.awfulRefreshControl) {
        self.awfulRefreshControl.userScrolling = NO;
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
    if (self.awfulRefreshControl) {
        self.awfulRefreshControl.state = AwfulRefreshControlStateNormal;
        self.awfulRefreshControl.loadedDate = [NSDate date];
    }
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

#pragma mark cells

- (void)configureCell:(UITableViewCell*)cell atIndexPath:(NSIndexPath *)indexPath {  
    //subclass must override
    abort();  
    
    //NSManagedObject *obj = (AwfulManagedObject*)[_fetchedResultsController objectAtIndexPath:indexPath];
    //[obj setContentForCell:cell];
}

@end
