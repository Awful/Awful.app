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

#define SECTION_INDEX_OFFSET 0

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

@end

@implementation AwfulForumsListController

#pragma mark -
#pragma mark Initialization

@synthesize favorites = _favorites;
@synthesize forums = _forums;
@synthesize forumSections = _forumSections;
@synthesize headerView = _headerView;


#pragma mark -
#pragma mark View lifecycle

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if([[segue identifier] isEqualToString:@"ThreadList"]) {
        NSIndexPath *selected = [self.tableView indexPathForSelectedRow];
        AwfulForum *forum = [self getForumAtIndexPath:selected];
        AwfulThreadListController *list = (AwfulThreadListController *)segue.destinationViewController;
        list.forum = forum;
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.favorites = [[NSMutableArray alloc] init];
    self.forums = [[NSMutableArray alloc] init];
    self.forumSections = [[NSMutableArray alloc] init];
    
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
    
    if([self.tableView numberOfSections] == 2 && isLoggedIn()) {
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
    NSData *arc = [[NSUserDefaults standardUserDefaults] valueForKey:@"favorites"];
    if(arc != nil) {
        self.favorites = [NSKeyedUnarchiver unarchiveObjectWithData:arc];
        if (self.favorites.count > 0)
            self.navigationItem.leftBarButtonItem = self.editButtonItem;

    }
}

-(void)saveFavorites
{
    if(self.favorites != nil) {
        NSData *arc = [NSKeyedArchiver archivedDataWithRootObject:self.favorites];
        [[NSUserDefaults standardUserDefaults] setValue:arc forKey:@"favorites"];
    }
}

-(BOOL)isAwfulForumSectionFavorited : (AwfulForumSection *)section
{
    for(AwfulForum *forum in self.favorites) {
        if([forum.forumID isEqualToString:section.forum.forumID]) {
            return YES;
        }
    }
    return NO;
}

-(void)toggleFavoriteForForumSection : (AwfulForumSection *)section
{    
    if(!isLoggedIn()) {
        return;
    }
    
    if([self isAwfulForumSectionFavorited:section]) {
        NSUInteger fav_index = NSNotFound;
        for(AwfulForum *forum in self.favorites) {
            if([forum.forumID isEqualToString:section.forum.forumID]) {
                fav_index = [self.favorites indexOfObject:forum];
            }
        }
        
        if(fav_index == NSNotFound) {
            NSLog(@"couldn't find index of favorited section to remove");
            return;
        }
        
        AwfulForumSection *bottom_section = [self getForumSectionFromID:section.forum.forumID];
        NSIndexPath *bottom_path = [self getIndexPathForSection:bottom_section];
        
        [self.favorites removeObjectAtIndex:fav_index];
        
        NSArray *remove = [NSArray arrayWithObject:[NSIndexPath indexPathForRow:fav_index inSection:0]];
        [self.tableView beginUpdates];
        
        // they may have favorited it but it might not be visible below
        if(bottom_path != nil) {
            [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:bottom_path] 
                              withRowAnimation:UITableViewRowAnimationNone];
        }
        
        [self.tableView deleteRowsAtIndexPaths:remove withRowAnimation:UITableViewRowAnimationBottom];
        [self.tableView endUpdates];
        
    } else {
        [self.favorites addObject:section.forum];
        
        NSIndexPath *reload_path = [self getIndexPathForSection:section];
        NSArray *reload = [NSArray arrayWithObject:reload_path];
        
        NSIndexPath *add_path = [NSIndexPath indexPathForRow:[self.favorites count]-1 inSection:0];
        NSArray *add = [NSArray arrayWithObject:add_path];
        
        [self.tableView beginUpdates];
        [self.tableView insertRowsAtIndexPaths:add withRowAnimation:UITableViewRowAnimationTop];
        [self.tableView reloadRowsAtIndexPaths:reload withRowAnimation:UITableViewRowAnimationNone];
        [self.tableView endUpdates];
    }
    [self saveFavorites];
    if (self.favorites.count > 0)
        self.navigationItem.leftBarButtonItem = self.editButtonItem;
    else
        self.navigationItem.leftBarButtonItem = nil;
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {

    if(!isLoggedIn()) {
        return 2;
    }
    
    // Return the number of sections.
    return [self.forumSections count] + SECTION_INDEX_OFFSET;// + 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    if(section == 0 && SECTION_INDEX_OFFSET > 0) {
        if(!isLoggedIn()) {
            return 0;
        }
        
        return [self.favorites count];
        
    }
    
    if(!isLoggedIn()) {
        return 0;
    }
    
    AwfulForumSection *root_section = [self getForumSectionAtSection:section];
    if(root_section.expanded) {
        NSMutableArray *descendants = [self getVisibleDescendantsListForForumSection:root_section];
        return [descendants count];
    }
    return 0;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"ForumCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    AwfulForumCell *forum_cell = (AwfulForumCell *)cell;
    forum_cell.forumsList = self;
    AwfulForumSection *section = [self getForumSectionAtIndexPath:indexPath];
    if(section != nil) {
        [forum_cell setSection:section];
    }

    return cell;
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

    if(section == 0 && SECTION_INDEX_OFFSET > 0) {
        str = @"Favorites";
    } else if(section == [self.forumSections count] + 1) {
        str = @"";
    } else {
        AwfulForumSection *forum_section = [self getForumSectionAtSection:section];
        if(forum_section != nil) {
            str = forum_section.forum.name;
        } else {
            str = @"Unknown";
        }
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
    
    if(indexPath.section == 0) {
        return YES;
    }
    
    return NO;
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [self toggleFavoriteForForumSection:[self getForumSectionAtIndexPath:indexPath]];
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
    [self saveFavorites];
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
    // Navigation logic may go here. Create and push another view controller.
	/*
	 <#DetailViewController#> *detailViewController = [[<#DetailViewController#> alloc] initWithNibName:@"<#Nib name#>" bundle:nil];
     // ...
     // Pass the selected object to the new view controller.
	 [self.navigationController pushViewController:detailViewController animated:YES];
	 [detailViewController release];
	 */
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
    if(section_index < SECTION_INDEX_OFFSET || section_index - SECTION_INDEX_OFFSET >= [self.forumSections count]) {
        return nil;
    }
    return [self.forumSections objectAtIndex:section_index-SECTION_INDEX_OFFSET];
}

-(NSUInteger)getSectionForForumSection : (AwfulForumSection *)forum_section
{
    AwfulForumSection *root_section = [self getRootSectionForSection:forum_section];
    NSUInteger index = [self.forumSections indexOfObject:root_section];
    if(index != NSNotFound) {
        return index + SECTION_INDEX_OFFSET;
    }
    return NSNotFound;
}

-(AwfulForum *)getForumAtIndexPath : (NSIndexPath *)path
{
    if(path.section == 0 && SECTION_INDEX_OFFSET > 0) {
        return [self.favorites objectAtIndex:path.row];
    } else {
        AwfulForumSection *section = [self getForumSectionAtIndexPath:path];
        return section.forum;
    }
    return nil;
}

-(AwfulForumSection *)getForumSectionAtIndexPath : (NSIndexPath *)path
{
    if(path.section == 0 && SECTION_INDEX_OFFSET > 0) {
        AwfulForum *forum = [self.favorites objectAtIndex:path.row];
        return [AwfulForumSection sectionWithForum:forum];
    }
    
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

@end

@implementation AwfulForumsListIpad

- (id) init {
    self = [super init];
    
    [self.navigationItem setTitle:@"Forum List"];

    self.tabBarItem.image = [UIImage imageNamed:@"list_icon.png"];
    self.tabBarItem.title = @"Forums";
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationItem.rightBarButtonItem = nil;
}

-(void)hitBookmarks
{
    AwfulBookmarksControllerIpad *bookmarks = [[AwfulBookmarksControllerIpad alloc] init];
    [self.navigationController pushViewController:bookmarks animated:YES];
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    //AwfulForum *forum = [self getForumAtIndexPath:indexPath];
    
    //AwfulThreadListIpad *detail = [[AwfulThreadListIpad alloc] initWithAwfulForum:forum];
    //[self.navigationController pushViewController:detail animated:YES];
}

@end
