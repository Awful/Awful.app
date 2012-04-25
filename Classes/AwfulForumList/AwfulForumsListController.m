//
//  AwfulForumsList.m
//  Awful
//
//  Created by Sean Berry on 7/27/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulForumsListController.h"
#import "AwfulForumsListControllerSubclass.h"
#import "AwfulThreadListController.h"
#import "AwfulAppDelegate.h"
#import "AwfulBookmarksController.h"
#import "AwfulForum.h"
#import "AwfulForum+AwfulMethods.h"
#import "AwfulForumCell.h"
#import "AwfulForumHeader.h"
#import "AwfulLoginController.h"
#import "AwfulNetworkEngine.h"
#import "AwfulSettings.h"
#import "AwfulUser.h"
#import "AwfulUtil.h"



@interface AwfulForumsListController ()

@property (nonatomic, strong) NSMutableArray *forums;

@property (nonatomic, strong) IBOutlet AwfulForumHeader *headerView;

@end

@implementation AwfulForumsListController

#pragma mark - Initialization

@synthesize forums = _forums;
@synthesize forumSections = _forumSections;
@synthesize headerView = _headerView;

- (NSPredicate *)forumsPredicate
{
    return nil;
}

#pragma mark - View lifecycle

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"ThreadList"]) {
        NSIndexPath *selected = [self.tableView indexPathForSelectedRow];
        
        AwfulForum *forum = [self getForumAtIndexPath:selected];
        AwfulThreadListController *list = (AwfulThreadListController *)segue.destinationViewController;
        list.forum = forum;
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self swapToRefreshButton];
    
    self.forums = [[NSMutableArray alloc] init];
    self.forumSections = [[NSMutableArray alloc] init];
    
    [self.navigationController setToolbarHidden:YES];
    
    [self loadForums];
        
    self.tableView.separatorColor = [UIColor colorWithRed:0.75 green:0.75 blue:0.75 alpha:1.0];
}

- (void)loadForums
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"AwfulForum"];
    NSSortDescriptor *sort = [[NSSortDescriptor alloc] initWithKey:@"index" ascending:YES];
    [fetchRequest setSortDescriptors:[NSArray arrayWithObject:sort]];
    fetchRequest.predicate = self.forumsPredicate;
    
    NSError *err = nil;
    NSArray *forums = [ApplicationDelegate.managedObjectContext executeFetchRequest:fetchRequest error:&err];
    if(err != nil) {
        NSLog(@"failed to load forums %@", [err localizedDescription]);
    }
    self.forums = [NSMutableArray arrayWithArray:forums];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setToolbarHidden:YES];
    
    [self.navigationItem.leftBarButtonItem setTintColor:[UIColor colorWithRed:46.0/255 green:146.0/255 blue:190.0/255 alpha:1.0]];
    
    if(IsLoggedIn() && [self.forums count] == 0) {
        [self refresh];
    } else if([self.tableView numberOfSections] == 0 && IsLoggedIn()) {
        [self.tableView reloadData];
    }
}

-(void)finishedRefreshing
{
    [super finishedRefreshing];
    [self swapToRefreshButton];
}

- (void)refresh
{
    [super refresh];
    [self swapToStopButton];
    [self.networkOperation cancel];
    self.networkOperation = [ApplicationDelegate.awfulNetworkEngine forumsListOnCompletion:^(NSMutableArray *forums) {
        
        self.forums = forums;
        [self finishedRefreshing];
        
    } onError:^(NSError *error) {
        [self finishedRefreshing];
        [AwfulUtil requestFailed:error];
    }];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return IsLoggedIn() ? [self.forumSections count] : 0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    
    if(!IsLoggedIn()) {
        return 0;
    }
    
    AwfulForumSection *rootSection = [self getForumSectionAtSection:section];
    if (rootSection.expanded) {
        NSMutableArray *descendants = [self getVisibleDescendantsListForForumSection:rootSection];
        return [descendants count];
    }
    
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"ForumCell";
    AwfulForumCell *cell = (AwfulForumCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    cell.forumsList = self;
    AwfulForumSection *section = [self getForumSectionAtIndexPath:indexPath];
    if (section) {
        cell.section = section;
    }
    return cell;
}

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

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    [[NSBundle mainBundle] loadNibNamed:@"AwfulForumHeaderView" owner:self options:nil];
    AwfulForumHeader *header = self.headerView;
    self.headerView = nil;
    
    AwfulForumSection *forumSection = [self getForumSectionAtSection:section];
    header.titleLabel.text = forumSection ? forumSection.forum.name : @"Unknown";
    return header;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 50;
}

#pragma mark - Forums

- (void)toggleExpandForForumSection:(AwfulForumSection *)section
{
    BOOL expanded = section.expanded;
    
    // need to set expanded to grab index list
    [section setExpanded:YES];
    NSMutableArray *childRows = [NSMutableArray array];
    for (AwfulForumSection *child in [self getVisibleDescendantsListForForumSection:section]) {
        [childRows addObject:[self getIndexPathForSection:child]];
    }
    
    section.expanded = !expanded;
    [self.tableView beginUpdates];
    if (expanded) {        
        [self.tableView deleteRowsAtIndexPaths:childRows withRowAnimation:UITableViewRowAnimationBottom];
    } else {
        [self.tableView insertRowsAtIndexPaths:childRows withRowAnimation:UITableViewRowAnimationMiddle];
    }
    NSArray *update = [NSArray arrayWithObject:[self getIndexPathForSection:section]];
    [self.tableView reloadRowsAtIndexPaths:update withRowAnimation:UITableViewRowAnimationNone];
    [self.tableView endUpdates];
}

- (void)setForums:(NSMutableArray *)forums
{
    if(forums != _forums) {
        _forums = forums;
        
        self.forumSections = nil;
        self.forumSections = [[NSMutableArray alloc] init];
        for(AwfulForum *forum in self.forums) {
            [self addForumToSectionTree:forum];
        }
        
        [self.tableView reloadData];
    }
}

#pragma mark - Tree Model Methods

-(void)addForumToSectionTree:(AwfulForum *)forum
{
    AwfulForumSection *section = [[AwfulForumSection alloc] init];
    section.forum = forum;

    if (forum.parentForum == nil) {
        [section setExpanded:YES];
        [self.forumSections addObject:section];
    } else {
        AwfulForumSection *parentSection = [self getForumSectionFromID:forum.parentForum.forumID];
        if (parentSection.rowIndex != NSNotFound) {
            [section setRowIndex:parentSection.rowIndex + [parentSection.children count]];
        } else {
            [section setRowIndex:[parentSection.children count]];
        }
        [parentSection.children addObject:section];
        
        int ancestors_count = 0;
        while (parentSection != nil) {
            ancestors_count++;
            parentSection = [self getForumSectionFromID:parentSection.forum.parentForum.forumID];
        }
        [section setTotalAncestors:ancestors_count];
    }
}

- (AwfulForumSection *)getForumSectionAtSection:(NSUInteger)sectionIndex
{
    if (sectionIndex >= [self.forumSections count]) {
        return nil;
    }
    return [self.forumSections objectAtIndex:sectionIndex];
}

- (NSUInteger)getSectionForForumSection:(AwfulForumSection *)forumSection
{
    AwfulForumSection *rootSection = [self getRootSectionForSection:forumSection];
    return [self.forumSections indexOfObject:rootSection];
}

- (AwfulForum *)getForumAtIndexPath:(NSIndexPath *)path
{
    AwfulForumSection *section = [self getForumSectionAtIndexPath:path];
    return section.forum;
}

- (AwfulForumSection *)getForumSectionAtIndexPath:(NSIndexPath *)path
{
    // TODO this goldmine stuff should not be here. Move it somewhere useful.
    if (!IsLoggedIn()) {
        if(path.section == 1) {
            NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"AwfulForum"];
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"forumID=21"];
            [fetchRequest setPredicate:predicate];
            NSError *err = nil;
            NSArray *results = [ApplicationDelegate.managedObjectContext executeFetchRequest:fetchRequest error:&err];

            if(err != nil) {
                NSLog(@"failed to find goldmine %@", [err localizedDescription]);
                return nil;
            }
            
            AwfulForum *goldmine = [AwfulForum getForumWithID:@"21" fromCurrentList:results];
            [goldmine setName:@"Comedy Goldmine"];
            AwfulForumSection *goldmine_section = [[AwfulForumSection alloc] init];
            goldmine_section.forum = goldmine;
            return goldmine_section;
        }
    }
    
    AwfulForumSection *big_section = [self getForumSectionAtSection:path.section];
    NSMutableArray *visible_descendants = [self getVisibleDescendantsListForForumSection:big_section];
    if (path.row < [visible_descendants count]) {
        return [visible_descendants objectAtIndex:path.row];
    }
    return nil;
}

- (NSMutableArray *)getVisibleDescendantsListForForumSection:(AwfulForumSection *)section
{
    if ([section.children count] == 0 || !section.expanded) {
        return [NSMutableArray array];
    }
    
    NSMutableArray *list = [NSMutableArray array];
    
    for (AwfulForumSection *child in section.children) {
        if (child.forum) {
            [list addObject:child];
        }
        [list addObjectsFromArray:[self getVisibleDescendantsListForForumSection:child]];
    }
    return list;
}

- (NSIndexPath *)getIndexPathForSection:(AwfulForumSection *)section
{
    if (section.forum.parentForum == nil) {
        return [NSIndexPath indexPathForRow:NSNotFound inSection:NSNotFound];
    }
    
    AwfulForumSection *rootSection = [self getRootSectionForSection:section];
    NSMutableArray *visibleDescendants = [self getVisibleDescendantsListForForumSection:rootSection];
    
    NSUInteger row = [visibleDescendants indexOfObject:section];
    NSUInteger sectionIndex = [self getSectionForForumSection:rootSection];
    if (row != NSNotFound && sectionIndex != NSNotFound) {
        return [NSIndexPath indexPathForRow:row inSection:sectionIndex];
    } else {
        NSLog(@"asking for index path of non-visible section");
        return nil;
    }
}

- (AwfulForumSection *)getForumSectionFromID:(NSString *)forumID
{
    for (AwfulForumSection *section in self.forumSections) {
        AwfulForumSection *winner = [self getForumSectionFromID:forumID lookInForumSection:section];
        if (winner != nil) {
            return winner;
        }
    }
    return nil;
}

- (AwfulForumSection *)getForumSectionFromID:(NSString *)forumID
                          lookInForumSection:(AwfulForumSection *)section
{
    if ([forumID isEqualToString:section.forum.forumID]) {
        return section;
    } else {
        for (AwfulForumSection *child in section.children) {
            AwfulForumSection *winner = [self getForumSectionFromID:forumID
                                                 lookInForumSection:child];
            if (winner != nil) {
                return winner;
            }
        }
    }
    return nil;
}

- (AwfulForumSection *)getRootSectionForSection:(AwfulForumSection *)section
{
    if (section.forum.parentForum == nil) {
        return section;
    }
    return [self getRootSectionForSection:[self getForumSectionFromID:section.forum.parentForum.forumID]];
}

@end

