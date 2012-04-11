//
//  AwfulForumsList.m
//  Awful
//
//  Created by Sean Berry on 7/27/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulForumsListController.h"
#import "AwfulForum.h"
#import "AwfulForum+AwfulMethods.h"
#import "AwfulThreadListController.h"
#import "AwfulAppDelegate.h"
#import "AwfulUtil.h"
#import "AwfulConfig.h"
#import "AwfulForumCell.h"
#import "AwfulLoginController.h"
#import "AwfulBookmarksController.h"
#import "AwfulUser.h"
#import "AwfulForumHeader.h"
#import "AwfulNetworkEngine.h"
#import "AwfulAddForumsViewController.h"

@implementation AwfulForumSection

@synthesize forum = _forum;
@synthesize children = _children;
@synthesize expanded = _expanded;
@synthesize rowIndex = _rowIndex;
@synthesize totalAncestors = _totalAncestors;

-(id)init
{
    if((self=[super init])) {
        self.forum = nil;
        self.children = [[NSMutableArray alloc] init];
        self.expanded = NO;
        self.rowIndex = NSNotFound;
        self.totalAncestors = 0;
    }
    return self;
}

+(AwfulForumSection *)sectionWithForum : (AwfulForum *)forum
{
    AwfulForumSection *sec = [[AwfulForumSection alloc] init];
    sec.forum = forum;
    return sec;
}

-(void)setAllExpanded
{
    self.expanded = YES;
    for(AwfulForumSection *section in self.children) {
        [section setAllExpanded];
    }
}

@end

@implementation AwfulForumsListController

#pragma mark -
#pragma mark Initialization

@synthesize favorites = _favorites;
@synthesize forums = _forums;
@synthesize forumSections = _forumSections;
@synthesize headerView = _headerView;
@synthesize displayingFullList = _displayingFullList;
@synthesize segmentedControl = _segmentedControl;

#pragma mark -
#pragma mark View lifecycle

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if([[segue identifier] isEqualToString:@"ThreadList"]) {
        NSIndexPath *selected = [self.tableView indexPathForSelectedRow];
        
        AwfulForum *forum = nil;
        if(self.displayingFullList) {
            forum = [self getForumAtIndexPath:selected];
        } else {
            forum = [self.favorites objectAtIndex:selected.row];
        }
        AwfulThreadListController *list = (AwfulThreadListController *)segue.destinationViewController;
        list.forum = forum;
    } else if([[segue identifier] isEqualToString:@"AddForums"]) {
        UINavigationController *nav = (UINavigationController *)segue.destinationViewController;
        AwfulAddForumsViewController *addForums = (AwfulAddForumsViewController *)nav.topViewController;
        addForums.delegate = self;
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.favorites = [[NSMutableArray alloc] init];
    self.forums = [[NSMutableArray alloc] init];
    self.forumSections = [[NSMutableArray alloc] init];
    self.displayingFullList = YES;
    
    [self.navigationController setToolbarHidden:YES];
    
    [self loadFavorites];
    [self loadForums];
        
    //UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(hitDone)];
    //self.navigationItem.rightBarButtonItem = done;
    
    if (self.favorites.count > 0) {
        self.navigationItem.leftBarButtonItem = self.editButtonItem;
    }
        
    self.tableView.separatorColor = [UIColor colorWithRed:0.75 green:0.75 blue:0.75 alpha:1.0];
}

-(void)loadForums
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"AwfulForum"];
    NSSortDescriptor *sort = [[NSSortDescriptor alloc] initWithKey:@"index" ascending:YES];
    [fetchRequest setSortDescriptors:[NSArray arrayWithObject:sort]];
    
    NSError *err = nil;
    NSArray *forums = [ApplicationDelegate.managedObjectContext executeFetchRequest:fetchRequest error:&err];
    if(err != nil) {
        NSLog(@"failed to load forums %@", [err localizedDescription]);
    }
    self.forums = [NSMutableArray arrayWithArray:forums];
}

-(void)hitDone
{
    //AwfulNavigator *nav = getNavigator();
    //[nav dismissModalViewControllerAnimated:YES];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setToolbarHidden:YES];
    
    [self.navigationItem.leftBarButtonItem setTintColor:[UIColor colorWithRed:46.0/255 green:146.0/255 blue:190.0/255 alpha:1.0]];
    
    if([self.tableView numberOfSections] == 0 && isLoggedIn()) {
        [self.tableView reloadData];
    }
}

/*
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}
*/
/*
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}
*/
/*
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}
*/

-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return YES;
}

-(void)refresh
{
    [super refresh];
    [self.networkOperation cancel];
    self.networkOperation = [ApplicationDelegate.awfulNetworkEngine forumsListOnCompletion:^(NSMutableArray *forums) {
        
        self.forums = forums;
        [self finishedRefreshing];
        
    } onError:^(NSError *error) {
        [self finishedRefreshing];
        [AwfulUtil requestFailed:error];
    }];
}

#pragma mark -
#pragma mark Favorites

-(void)loadFavorites
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"AwfulForum"];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"favorited==YES"];
    [fetchRequest setPredicate:predicate];
    
    NSError *err = nil;
    NSArray *results = [ApplicationDelegate.managedObjectContext executeFetchRequest:fetchRequest error:&err];
    if(err != nil) {
        NSLog(@"failed to get favorite forums: %@", [err localizedDescription]);
        return;
    }
    self.favorites = [NSMutableArray arrayWithArray:results];
}

-(void)toggleFavoriteForForum : (AwfulForum *)forum
{    
    if(!isLoggedIn()) {
        return;
    }
    
    if([forum.favorited boolValue]) {
        forum.favorited = [NSNumber numberWithBool:NO];
    } else {
        forum.favorited = [NSNumber numberWithBool:YES];
    }
    [ApplicationDelegate saveContext];
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {

    if(!isLoggedIn()) {
        return 0;
    }
    
    if(self.displayingFullList) {
        return [self.forumSections count];
    } else {
        return 1;
    }
    
    return 0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    if(!isLoggedIn()) {
        return 0;
    }
    
    if(self.displayingFullList) {
        AwfulForumSection *root_section = [self getForumSectionAtSection:section];
        if(root_section.expanded) {
            NSMutableArray *descendants = [self getVisibleDescendantsListForForumSection:root_section];
            return [descendants count];
        }
    } else {
        return [self.favorites count] + 1;
    }
    
    return 0;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if(self.displayingFullList || indexPath.row < [self.favorites count]) {
        static NSString *CellIdentifier = @"ForumCell";
        
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        AwfulForumCell *forum_cell = (AwfulForumCell *)cell;
        forum_cell.forumsList = self;
        
        if(self.displayingFullList) {
            AwfulForumSection *section = [self getForumSectionAtIndexPath:indexPath];
            if(section != nil) {
                [forum_cell setSection:section];
            }
        } else {
            AwfulForum *forum = [self.favorites objectAtIndex:indexPath.row];
            AwfulForumSection *section = [AwfulForumSection sectionWithForum:forum];
            if(section != nil && forum != nil) {
                [forum_cell setSection:section];
            }
        }

        return cell;
    } else if(!self.displayingFullList && indexPath.row == [self.favorites count]) {
        static NSString *ident = @"AddFavoritesCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:ident];
        return cell;
    }
    return nil;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    // need to set background color here to make it work on the disclosure indicator
    AwfulForumSection *section = [self getForumSectionAtIndexPath:indexPath];
    AwfulForumCell *forum_cell = (AwfulForumCell *)cell;
    if(section.totalAncestors > 1) {
        UIColor *gray = [UIColor colorWithRed:235.0/255 green:235.0/255 blue:236.0/255 alpha:1.0];
        cell.backgroundColor = gray;
        forum_cell.titleLabel.backgroundColor = gray;
    } else {
        cell.backgroundColor = [UIColor whiteColor];
        forum_cell.titleLabel.backgroundColor = [UIColor whiteColor];
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    NSString *str = nil;
    
    if(self.displayingFullList) {
        AwfulForumSection *forum_section = [self getForumSectionAtSection:section];
        if(forum_section != nil) {
            str = forum_section.forum.name;
        } else {
            str = @"Unknown";
        }
    } else {
        str = @"Favorites";
    }
    
    AwfulForumHeader *header = nil;
    [[NSBundle mainBundle] loadNibNamed:@"AwfulForumHeaderView" owner:self options:nil];
    header = self.headerView;
    self.headerView = nil;
    [header.titleLabel setText:str];
    return header;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 50;
}


// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    
    if(self.displayingFullList) {
        return YES;
    } else {
        return NO;
    }
    
    return NO;
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [self toggleFavoriteForForum:[self getForumAtIndexPath:indexPath]];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}


// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
    
    NSUInteger old_row = fromIndexPath.row;
    NSUInteger to_row = toIndexPath.row;
    
    AwfulForum *fav = [self.favorites objectAtIndex:old_row];
    [self.favorites removeObject:fav];
    [self.favorites insertObject:fav atIndex:to_row];
}



/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/


#pragma mark -
#pragma mark Table view delegate


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if(!self.displayingFullList && indexPath.row == [self.favorites count]) {
        [self performSegueWithIdentifier:@"AddForums" sender:nil];
    }
}

#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Relinquish ownership any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    // Relinquish ownership of anything that can be recreated in viewDidLoad or on demand.
    // For example: self.myOutlet = nil;
}

#pragma mark -
#pragma mark Forums

-(void)toggleExpandForForumSection : (AwfulForumSection *)section
{
    NSArray *update = [NSArray arrayWithObject:[self getIndexPathForSection:section]];
    BOOL expanded = section.expanded;
    
    // need to set expanded to grab index list
    [section setExpanded:YES];
    NSMutableArray *child_rows = [NSMutableArray array];
    NSMutableArray *visible_descendants = [self getVisibleDescendantsListForForumSection:section];
    for(AwfulForumSection *child in visible_descendants) {
        NSIndexPath *child_path = [self getIndexPathForSection:child];
        [child_rows addObject:child_path];
    }
    
    if(expanded) {        
        [section setExpanded:NO];
        [self.tableView beginUpdates];
        [self.tableView deleteRowsAtIndexPaths:child_rows withRowAnimation:UITableViewRowAnimationBottom];
        [self.tableView reloadRowsAtIndexPaths:update withRowAnimation:UITableViewRowAnimationNone];
        [self.tableView endUpdates];
    } else {
        [section setExpanded:YES];
        [self.tableView beginUpdates];
        [self.tableView insertRowsAtIndexPaths:child_rows withRowAnimation:UITableViewRowAnimationMiddle];
        [self.tableView reloadRowsAtIndexPaths:update withRowAnimation:UITableViewRowAnimationNone];
        [self.tableView endUpdates];
    }
}

-(IBAction)grabFreshList
{
    /*AwfulForumListRefreshRequest *req = [[AwfulForumListRefreshRequest alloc] initWithForumsList:self];
    loadRequestAndWait(req);*/
}

-(void)setForums:(NSMutableArray *)forums
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

#pragma mark -
#pragma mark Tree Model Methods

-(void)addForumToSectionTree : (AwfulForum *)forum
{
    AwfulForumSection *section = [[AwfulForumSection alloc] init];
    section.forum = forum;

    if(forum.parentForum == nil) {
        [section setExpanded:YES];
        [self.forumSections addObject:section];
    } else {
        AwfulForumSection *parent_section = [self getForumSectionFromID:forum.parentForum.forumID];
        if(parent_section.rowIndex != NSNotFound) {
            [section setRowIndex:parent_section.rowIndex + [parent_section.children count]];
        } else {
            [section setRowIndex:[parent_section.children count]];
        }
        [parent_section.children addObject:section];
        
        int ancestors_count = 0;
        while(parent_section != nil) {
            ancestors_count++;
            parent_section = [self getForumSectionFromID:parent_section.forum.parentForum.forumID];
        }
        [section setTotalAncestors:ancestors_count];
    }
}

-(AwfulForumSection *)getForumSectionAtSection : (NSUInteger)section_index
{
    if(section_index >= [self.forumSections count]) {
        return nil;
    }
    return [self.forumSections objectAtIndex:section_index];
}

-(NSUInteger)getSectionForForumSection : (AwfulForumSection *)forum_section
{
    AwfulForumSection *root_section = [self getRootSectionForSection:forum_section];
    NSUInteger index = [self.forumSections indexOfObject:root_section];
    if(index != NSNotFound) {
        return index;
    }
    return NSNotFound;
}

-(AwfulForum *)getForumAtIndexPath : (NSIndexPath *)path
{
    AwfulForumSection *section = [self getForumSectionAtIndexPath:path];
    return section.forum;
}

-(AwfulForumSection *)getForumSectionAtIndexPath : (NSIndexPath *)path
{
    if(!isLoggedIn()) {
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
    if(path.row < [visible_descendants count]) {
        return [visible_descendants objectAtIndex:path.row];
    }
    return nil;
}

-(NSMutableArray *)getVisibleDescendantsListForForumSection : (AwfulForumSection *)section
{
    if([section.children count] == 0 || !section.expanded) {
        return [NSMutableArray array];
    }
    
    NSMutableArray *list = [NSMutableArray array];
    
    for(AwfulForumSection *child in section.children) {
        [list addObject:child];
        [list addObjectsFromArray:[self getVisibleDescendantsListForForumSection:child]];
    }
    return list;
}

-(NSIndexPath *)getIndexPathForSection : (AwfulForumSection *)section
{
    if(section.forum.parentForum == nil) {
        return [NSIndexPath indexPathForRow:NSNotFound inSection:NSNotFound];
    }
    
    AwfulForumSection *root_section = [self getRootSectionForSection:section];
    NSMutableArray *visible_descendants = [self getVisibleDescendantsListForForumSection:root_section];
    
    NSUInteger row = [visible_descendants indexOfObject:section];
    NSUInteger section_index = [self getSectionForForumSection:root_section];
    if(row != NSNotFound && section_index != NSNotFound) {
        return [NSIndexPath indexPathForRow:row inSection:section_index];
    } else {
        NSLog(@"asking for index path of non-visible section");
        return nil;
    }
    
    return nil;
}

-(AwfulForumSection *)getForumSectionFromID : (NSString *)forum_id
{
    AwfulForumSection *winner = nil;
    for(AwfulForumSection *section in self.forumSections) {
        winner = [self getForumSectionFromID:forum_id lookInForumSection:section];
        if(winner != nil) {
            return winner;
        }
    }
    return winner;
}

-(AwfulForumSection *)getForumSectionFromID : (NSString *)forum_id lookInForumSection : (AwfulForumSection *)section
{
    if([forum_id isEqualToString:section.forum.forumID]) {
        return section;
    } else {
        for(AwfulForumSection *child in section.children) {
            AwfulForumSection *winner = [self getForumSectionFromID:forum_id lookInForumSection:child];
            if(winner != nil) {
                return winner;
            }
        }
    }
    return nil;
}

-(AwfulForumSection *)getRootSectionForSection : (AwfulForumSection *)section
{
    if(section.forum.parentForum == nil) {
        return section;
    }
    return [self getRootSectionForSection:[self getForumSectionFromID:section.forum.parentForum.forumID]];
}

-(IBAction)segmentedControlChanged:(id)sender
{
    self.displayingFullList = (self.segmentedControl.selectedSegmentIndex == 0);
    [self.tableView reloadData];
}

@end

