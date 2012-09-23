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
#import "AwfulForum+AwfulMethods.h"
#import "AwfulForumHeader.h"
#import "AwfulLoginController.h"
#import "AwfulSettings.h"
#import "AwfulParentForumCell.h"
#import "AwfulSubForumCell.h"
#import "AwfulCustomForums.h"

@interface AwfulForumsListController () <AwfulParentForumCellDelegate>

@property (nonatomic, strong) IBOutlet AwfulForumHeader *headerView;

@end

@implementation AwfulForumsListController

- (NSFetchedResultsController *)createFetchedResultsController
{
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:[AwfulForum entityName]];
    request.predicate = [NSPredicate predicateWithFormat:@"parentForum == nil or parentForum.expanded == YES"];
    request.sortDescriptors = @[
        [NSSortDescriptor sortDescriptorWithKey:@"category.index" ascending:YES],
        [NSSortDescriptor sortDescriptorWithKey:@"index" ascending:YES]
    ];
    return [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                               managedObjectContext:ApplicationDelegate.managedObjectContext
                                                 sectionNameKeyPath:@"category.index"
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
    self.networkOperation = [[AwfulHTTPClient sharedClient] forumsListOnCompletion:^(NSArray *listOfForums)
    {
        [self finishedRefreshing];
        [self.fetchedResultsController performFetch:NULL];
        [self.tableView reloadData];
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
    
    AwfulForum *anyForum = [[self.fetchedResultsController.sections[section] objects] lastObject];
    header.titleLabel.text = anyForum.category.name;
    return header;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 26;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulForum *forum = [self.fetchedResultsController objectAtIndexPath:indexPath];
    NSString *cellIdentifier = [forum.children count] ? @"AwfulParentForumCell" : @"AwfulSubForumCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (void)configureCell:(UITableViewCell *)plainCell atIndexPath:(NSIndexPath*)indexPath
{
    AwfulForumCell *cell = (AwfulForumCell *)plainCell;
    AwfulForum *forum = [self.fetchedResultsController objectAtIndexPath:indexPath];
    cell.forum = forum;
    if ([cell isKindOfClass:[AwfulParentForumCell class]])
        ((AwfulParentForumCell *)cell).delegate = self;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulForum *forum = [self.fetchedResultsController objectAtIndexPath:indexPath];
    Class cellClass = forum.parentForum ? [AwfulSubForumCell class] : [AwfulParentForumCell class];
    return [cellClass heightForContent:forum inTableView:tableView];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulForum *forum = [self.fetchedResultsController objectAtIndexPath:indexPath];
    AwfulThreadListController *threadList = [AwfulCustomForums threadListControllerForForum:forum];
    threadList.forum = forum;
    [self.navigationController pushViewController:threadList animated:YES];
}

#pragma mark - Parent forum cell delegate

- (void)parentForumCellDidToggleExpansion:(AwfulParentForumCell *)cell
{
    cell.forum.expandedValue = cell.expanded;
    [ApplicationDelegate saveContext];
    
    // The fetched results controller won't pick up on changes to the keypath "parentForum.expanded"
    // so we need to help it along. (Not sure why it needs this...)
    for (AwfulForum *child in cell.forum.children) {
        [child willChangeValueForKey:AwfulForumRelationships.parentForum];
        [child didChangeValueForKey:AwfulForumRelationships.parentForum];
    }
}

@end

