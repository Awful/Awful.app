//
//  AwfulForumsListController.m
//  Awful
//
//  Created by Sean Berry on 7/27/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulForumsListController.h"
#import "AwfulFetchedTableViewControllerSubclass.h"
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

- (NSFetchedResultsController *)createFetchedResultsController
{
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:[AwfulForum entityName]];
    request.predicate = [NSPredicate predicateWithFormat:@"children.@count > 0 or parentForum.expanded = YES"];
    request.sortDescriptors = @[
        [NSSortDescriptor sortDescriptorWithKey:@"category.index" ascending:YES],
        [NSSortDescriptor sortDescriptorWithKey:@"index" ascending:YES]
    ];
    return [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                               managedObjectContext:ApplicationDelegate.managedObjectContext
                                                 sectionNameKeyPath:@"category.name"
                                                          cacheName:nil];
}

#pragma mark - View lifecycle

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    UITableViewCell* cell = (UITableViewCell*)sender;
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    
    AwfulThreadListController *list = (AwfulThreadListController *)segue.destinationViewController;
    list.forum = [self.fetchedResultsController objectAtIndexPath:indexPath];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(toggleExpandForumCell:)
                                                 name:AwfulToggleExpandForum
                                               object:nil];

    [self.navigationController setToolbarHidden:YES];
    
    self.tableView.separatorColor = [UIColor colorWithRed:0.75 green:0.75 blue:0.75 alpha:1.0];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self.navigationController setToolbarHidden:YES];
    
    [self.navigationItem.leftBarButtonItem setTintColor:[UIColor colorWithRed:46.0/255 green:146.0/255 blue:190.0/255 alpha:1.0]];
    
    if (IsLoggedIn() && [self.fetchedResultsController.sections count] == 0) {
       [self refresh];
    }
    
    //reset this since it may get changed by custom forums
    [self.navigationController.navigationBar setBackgroundImage:[ApplicationDelegate navigationBarBackgroundImageForMetrics:UIBarMetricsDefault]
                                                  forBarMetrics:(UIBarMetricsDefault)];
}

- (void)refresh
{
    [super refresh];
    [self.networkOperation cancel];
    self.networkOperation = [[AwfulHTTPClient sharedClient] forumsListOnCompletion:^(id _)
    {
        [self finishedRefreshing];
    } onError:^(NSError *error)
    {
        [self finishedRefreshing];
        [ApplicationDelegate requestFailed:error];
    }];
}

- (void)stop
{
    [self.networkOperation cancel];
    [self finishedRefreshing];
}

#pragma mark - Table view data source

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    [[NSBundle mainBundle] loadNibNamed:@"AwfulForumHeaderView" owner:self options:nil];
    AwfulForumHeader *header = self.headerView;
    self.headerView = nil;
    
    header.titleLabel.text = [self.fetchedResultsController.sections[section] name];
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
 

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath*)indexPath
{
    AwfulParentForumCell *forumCell = (AwfulParentForumCell *)cell;
    AwfulForum *forum = [self.fetchedResultsController objectAtIndexPath:indexPath];
    forumCell.forum = forum;
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
    for (NSUInteger i = indexPath.row+1; i <= indexPath.row + forum.children.count; i++) {
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

