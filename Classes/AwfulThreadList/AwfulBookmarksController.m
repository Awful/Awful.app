//
//  BookmarksController.m
//  Awful
//
//  Created by Sean Berry on 7/26/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulBookmarksController.h"
#import "AwfulNetworkEngine.h"
#import "AwfulPage.h"
#import "AwfulPageCount.h"
#import "AwfulSettings.h"
#import "AwfulTableViewController.h"
#import "AwfulThread.h"
#import "AwfulThreadCell.h"
#import "AwfulThread+AwfulMethods.h"
#import "AwfulUtil.h"
#import "AwfulLoginController.h"

@implementation AwfulBookmarksController

@synthesize threadCount = _threadCount;

-(void)awakeFromNib
{
    [super awakeFromNib];
        
    self.tableView.delegate = self;
    self.title = @"Bookmarks";
}

#pragma mark -
#pragma mark View lifecycle

-(void)viewDidLoad {
    [super viewDidLoad];
    
    // moving the auto refresh to viewWillAppear, because bookmarks get loaded right away because of the tabbarcontroller, even if the user isn't looking at them
    self.navigationItem.leftBarButtonItem = self.editButtonItem;
    
    UIBarButtonItem *back = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"bookmarks.png"] style:UIBarButtonItemStyleBordered target:nil action:nil];
    self.navigationItem.backBarButtonItem = back;
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setToolbarHidden:YES];
    [[self.navigationController navigationBar] setTintColor:[UIColor colorWithRed:0 green:91.0/255 blue:135.0/255 alpha:1.0]];
    
    if(IsLoggedIn() && ([self.awfulThreads count] == 0 || UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ) {
        [self refresh];
    }
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

-(void)awfulThreadUpdated : (NSNotification *)notif
{
    [super awfulThreadUpdated:notif];
    
    AwfulThread *changedThread = [notif object];
    NSIndexPath *path = nil;
    for(AwfulThread *thread in self.awfulThreads) {
        if(thread == changedThread && ![thread.isBookmarked boolValue]) {
            path = [NSIndexPath indexPathForRow:[self.awfulThreads indexOfObject:thread] inSection:0];
        }
    }
    if(path != nil) {
        [self.awfulThreads removeObject:changedThread];
        [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:path] withRowAnimation:UITableViewRowAnimationFade];
    }
}

-(void)loadThreads
{
    NSArray *threads = [AwfulThread bookmarkedThreads];
    [self acceptThreads:[NSMutableArray arrayWithArray:threads]];
}

-(BOOL)shouldReloadOnViewLoad
{
    return NO;
}

-(void)acceptThreads:(NSMutableArray *)in_threads
{
    self.threadCount = [self.awfulThreads count] + [in_threads count]; // this needs to be before the super call
    [super acceptThreads:in_threads];
}

-(void)loadPageNum : (NSUInteger)pageNum
{   
    [self.networkOperation cancel];
    self.networkOperation = [ApplicationDelegate.awfulNetworkEngine threadListForBookmarksAtPageNum:pageNum onCompletion:^(NSMutableArray *threads) {
        self.pages.currentPage = pageNum;
        if(pageNum == 1) {
            [self.awfulThreads removeAllObjects];
        }
        [self acceptThreads:threads];
        [self finishedRefreshing];
        
    } onError:^(NSError *error) {
        [self finishedRefreshing];
        [AwfulUtil requestFailed:error];
    }];
}

-(BOOL)moreThreads
{
    if(self.threadCount % 40 == 0 && [self.awfulThreads count] > 0) {
        return YES;
    }
    return NO;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    if(indexPath.row == [self.awfulThreads count]) {
        return NO;
    }
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        
        AwfulThread *thread = [self.awfulThreads objectAtIndex:indexPath.row];
        [self.awfulThreads removeObject:thread];   
        [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:YES];
        
        self.networkOperation = [ApplicationDelegate.awfulNetworkEngine removeBookmarkedThread:thread onCompletion:^(void) {
            
        } onError:^(NSError *error) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Failed" message:[error localizedDescription] delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
            [alert show];
        }];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}

@end
