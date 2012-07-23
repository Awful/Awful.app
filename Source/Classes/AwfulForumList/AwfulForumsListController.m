//
//  AwfulForumsList.m
//  Awful
//
//  Created by Sean Berry on 7/27/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulForumsListController.h"
#import "AwfulThreadListController.h"
#import "AwfulAppDelegate.h"
#import "AwfulBookmarksController.h"
#import "AwfulForum.h"
#import "AwfulForum+AwfulMethods.h"
#import "AwfulForumHeader.h"
#import "AwfulLoginController.h"
#import "AwfulSettings.h"
#import "AwfulUser.h"
#import "AwfulParentForumCell.h"
#import "AwfulSubForumCell.h"
#import "AwfulCustomForums.h"

@interface AwfulForumsListController ()

@property (nonatomic, strong) IBOutlet AwfulForumHeader *headerView;

@end

@implementation AwfulForumsListController

#pragma mark - Initialization

@synthesize headerView = _headerView;


#pragma mark - View lifecycle

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    
    //if ([[segue identifier] isEqualToString:@"ThreadList"]) {
        UITableViewCell* cell = (UITableViewCell*)sender;
        NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
        
        AwfulThreadListController *list = (AwfulThreadListController *)segue.destinationViewController;
        list.forum = [self.fetchedResultsController objectAtIndexPath:indexPath];
    //}
     
}

-(void) awakeFromNib {
      
    [self setEntityName:@"AwfulForum"
              predicate:@"category != nil and (children.@count >0 or parentForum.expanded = YES)"
                   sort: [NSArray arrayWithObjects:
                          [NSSortDescriptor sortDescriptorWithKey:@"category.index" ascending:YES],
                          [NSSortDescriptor sortDescriptorWithKey:@"index" ascending:YES],
                          nil]
             sectionKey:@"category.index"
     ];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(toggleExpandForumCell:) 
                                                 name:AwfulToggleExpandForum
                                               object:nil
     ];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self.navigationController setToolbarHidden:YES];
    
    self.tableView.separatorColor = [UIColor colorWithRed:0.75 green:0.75 blue:0.75 alpha:1.0];
}



- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setToolbarHidden:YES];
    
    [self.navigationItem.leftBarButtonItem setTintColor:[UIColor colorWithRed:46.0/255 green:146.0/255 blue:190.0/255 alpha:1.0]];
    
   if(IsLoggedIn() && self.fetchedResultsController.sections.count == 0) {
       [self refresh];
    }
    
    //reset this since it may get changed by custom forums
    [self.navigationController.navigationBar setBackgroundImage:[ApplicationDelegate navigationBarBackgroundImageForMetrics:UIBarMetricsDefault]
                                                  forBarMetrics:(UIBarMetricsDefault)];
    
    
}

-(void)finishedRefreshing
{
    [super finishedRefreshing];
}

- (void)refresh
{
    [super refresh];
    [self.networkOperation cancel];
    self.networkOperation = [[AwfulHTTPClient sharedClient] forumsListOnCompletion:^(NSMutableArray *forums) {
        
        [self finishedRefreshing];
        
    } onError:^(NSError *error) {
        [self finishedRefreshing];
        [ApplicationDelegate requestFailed:error];
    }];
}

-(void)stop
{
    [self.networkOperation cancel];
    [self finishedRefreshing];
}

#pragma mark - Table view data source
/*

- (void)tableView:(UITableView *)tableView
  willDisplayCell:(UITableViewCell *)cell
forRowAtIndexPath:(NSIndexPath *)indexPath
{
    // need to set background color here to make it work on the disclosure indicator
    AwfulForumSection *section = [self getForumSectionAtIndexPath:indexPath];
    AwfulForumCell *forumCell = (AwfulForumCell *)cell;
    if (section.totalAncestors > 1) {
        UIColor *gray = [UIColor colorWithRed:235.0/255 green:235.0/255 blue:236.0/255 alpha:1.0];
        cell.backgroundColor = gray;
        forumCell.titleLabel.backgroundColor = gray;
    } else {
        cell.backgroundColor = [UIColor whiteColor];
        forumCell.titleLabel.backgroundColor = [UIColor whiteColor];
    }
}

*/
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    [[NSBundle mainBundle] loadNibNamed:@"AwfulForumHeaderView" owner:self options:nil];
    AwfulForumHeader *header = self.headerView;
    self.headerView = nil;
    
    header.titleLabel.text = [self.fetchedResultsController.sectionIndexTitles objectAtIndex:section];
    return header;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 30;
}


- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulForum* forum = [self.fetchedResultsController objectAtIndexPath:indexPath];
    NSString* cellIdentifier;
    if (forum.parentForum == nil)
        cellIdentifier = @"AwfulParentForumCell";
    else {
        cellIdentifier = @"AwfulSubForumCell";
    }
    
    UITableViewCell *cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}
 

-(void) configureCell:(AwfulParentForumCell*)cell atIndexPath:(NSIndexPath*)indexPath {
    AwfulForum* forum = [self.fetchedResultsController objectAtIndexPath:indexPath];
    cell.forum = forum;
}

-(CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    AwfulForum* forum = [self.fetchedResultsController objectAtIndexPath:indexPath];
    if (forum.parentForum == nil)
        return [AwfulParentForumCell heightForContent:forum inTableView:tableView];
    else
        return [AwfulSubForumCell heightForContent:forum inTableView:tableView];

}

-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    AwfulForum* forum = [self.fetchedResultsController objectAtIndexPath:indexPath];
    AwfulThreadListController *threadList = [AwfulCustomForums threadListControllerForForum:forum];
    threadList.forum = forum;
    [self.navigationController pushViewController:threadList animated:YES];
}

#pragma mark - Forums

-(void) toggleExpandForumCell:(NSNotification*)msg {
    AwfulParentForumCell* cell = msg.object;
    BOOL toggle = [[msg.userInfo objectForKey:@"toggle"] boolValue];
    
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    AwfulForum* forum = [self.fetchedResultsController objectAtIndexPath:indexPath];
    
    forum.expandedValue = toggle;
    //NSLog(@"pre count: %i", [[[self.fetchedResultsController sections] objectAtIndex:indexPath.section] numberOfObjects]);
    [ApplicationDelegate saveContext];
    
    
    NSMutableArray* rows = [NSMutableArray new];
    for (int i=indexPath.row+1; i<=indexPath.row+forum.children.count; i++) {
        [rows addObject:[NSIndexPath indexPathForRow:i inSection:indexPath.section]];
    }
    
    [self.tableView beginUpdates];

    [self.fetchedResultsController performFetch:nil];
    //NSLog(@"post count: %i", [[[self.fetchedResultsController sections] objectAtIndex:indexPath.section] numberOfObjects]);
    if (toggle) 
         [self.tableView insertRowsAtIndexPaths:rows withRowAnimation:(UITableViewRowAnimationTop)];
    else
         [self.tableView deleteRowsAtIndexPaths:rows withRowAnimation:(UITableViewRowAnimationTop)];
         
    [self.tableView endUpdates];
        
}

@end

