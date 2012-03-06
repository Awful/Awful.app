//
//  AwfulTableViewController.m
//  Awful
//
//  Created by Sean Berry on 2/29/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulTableViewController.h"
#import "AwfulConfig.h"

@implementation AwfulTableViewController

@synthesize refreshTimer = _refreshTimer;
@synthesize networkOperation = _networkOperation;

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

#pragma mark - View Cycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self startTimer];
}

#pragma mark - Refresh

-(void)refresh
{
    [self endTimer];
    /*[UIView animateWithDuration:0.2 animations:^(void){
        self.view.alpha = 0.5;
    }];*/
    [self swapToStopButton];
}

-(void)stop
{
    /*self.view.userInteractionEnabled = YES;
    [UIView animateWithDuration:0.2 animations:^(void){
        self.view.alpha = 1.0;
    }];*/
    [self swapToRefreshButton];
    [self.networkOperation cancel];
}

-(void)startTimer
{
    [self endTimer];
    float delay = [AwfulConfig bookmarksDelay];
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:delay target:self selector:@selector(refresh) userInfo:nil repeats:NO];
}

-(void)endTimer
{
    if([self.refreshTimer isValid]) {
        [self.refreshTimer invalidate];
    }
    self.refreshTimer = nil;
}

-(void)swapToRefreshButton
{
    UIBarButtonItem *refresh = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refresh)];
    self.navigationItem.rightBarButtonItem = refresh;
}

-(void)swapToStopButton
{
    UIBarButtonItem *stop = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(stop)];
    self.navigationItem.rightBarButtonItem = stop;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

@end
