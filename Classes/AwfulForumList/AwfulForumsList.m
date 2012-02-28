//
//  AwfulForumsList.m
//  Awful
//
//  Created by Sean Berry on 7/27/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulForumsList.h"
#import "AwfulForum.h"
#import "AwfulThreadList.h"
#import "AwfulNavigator.h"
#import "AwfulAppDelegate.h"
#import "AwfulNavigator.h"
#import "AwfulUtil.h"
#import "AwfulConfig.h"
#import "AwfulForumCell.h"
#import "AwfulLoginController.h"
#import "AwfulBookmarksController.h"
#import "AwfulUser.h"
#import "AwfulForumHeader.h"
#import "AwfulNetworkEngine.h"

#define SECTION_INDEX_OFFSET 1

@implementation AwfulForumSection

@synthesize forum, children, expanded, rowIndex, totalAncestors;

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

@implementation AwfulForumsList

#pragma mark -
#pragma mark Initialization

@synthesize favorites, forums, forumSections;
@synthesize forumCell, headerView, refreshCell;

/*
-(id)initWithCoder:(NSCoder *)aDecoder
{
    return [self init];
}*/

#pragma mark -
#pragma mark View lifecycle

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if([[segue identifier] isEqualToString:@"ThreadList"]) {
        NSIndexPath *selected = [self.tableView indexPathForSelectedRow];
        AwfulForum *forum = [self getForumAtIndexPath:selected];
        AwfulThreadList *list = (AwfulThreadList *)segue.destinationViewController;
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
    self.tableView.backgroundColor = [UIColor colorWithRed:0 green:0.4 blue:0.6 alpha:1.0];
}

-(void)hitDone
{
    AwfulNavigator *nav = getNavigator();
    [nav dismissModalViewControllerAnimated:YES];
}

/*
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}
*/
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
    if(section == 0) {
        if(!isLoggedIn()) {
            return 0;
        }
        
        return [self.favorites count];
        
    } else if([self isRefreshSection:[NSIndexPath indexPathForRow:0 inSection:section]]) {
        return 1;
    }
    
    if(!isLoggedIn()) {
        return 1;
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
    static NSString *refreshIdentifier = @"RefreshCell";
    
    NSString *ident = CellIdentifier;
    
    if([self isRefreshSection:indexPath]) {
        ident = refreshIdentifier;
    }
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:ident];
    /*if (cell == nil) {
        if(ident == CellIdentifier) {
            [[NSBundle mainBundle] loadNibNamed:@"AwfulForumCell" owner:self options:nil];
            self.forumCell.forumsList = self;
            cell = self.forumCell;
            self.forumCell = nil;
        } else if(ident == refreshIdentifier) {
            [[NSBundle mainBundle] loadNibNamed:@"AwfulForumRefreshButton" owner:self options:nil];
            cell = self.refreshCell;
            self.refreshCell = nil;
        }
    }*/
    
    if(ident == CellIdentifier) {
        AwfulForumCell *forum_cell = (AwfulForumCell *)cell;
        forum_cell.forumsList = self;
        AwfulForumSection *section = [self getForumSectionAtIndexPath:indexPath];
        if(section != nil) {
            [forum_cell setSection:section];
        }
    }
    return cell;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    NSString *str = nil;

    if(section == 0) {
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
    
    AwfulForum *forum = [self getForumAtIndexPath:indexPath];
    AwfulThreadList *detail = [[AwfulThreadList alloc] initWithAwfulForum:forum];
    loadContentVC(detail);
    //[detail release];
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

-(void)setForums:(NSMutableArray *)in_forums
{
    forums = in_forums;
    self.forumSections = nil;
    self.forumSections = [[NSMutableArray alloc] init];
    for(AwfulForum *forum in self.forums) {
        [self addForumToSectionTree:forum];
    }
    [self saveForums];
    
    [self.tableView reloadData];
}

-(void)loadForums
{
    NSString *path = [[AwfulUtil getDocsDir] stringByAppendingPathComponent:@"forumslist"];
    if([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSMutableArray *data = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
        if([data count] == 0) {
            [self grabFreshList];
        } else {
            self.forums = data;
        }
    } else {
        NSString *bundle_path = [[NSBundle mainBundle] pathForResource:@"forumslist" ofType:@""];
        BOOL success = [[NSFileManager defaultManager] copyItemAtPath:bundle_path toPath:path error:nil];
        if(success) {
            [self loadForums];
        } else {
            [self grabFreshList];
        }
    }
}

-(void)saveForums
{
    if(self.forums == nil || [self.forums count] == 0) {
        return;
    }
    
    NSString *path = [[AwfulUtil getDocsDir] stringByAppendingPathComponent:@"forumslist"];
    BOOL success = [NSKeyedArchiver archiveRootObject:self.forums toFile:path];
    if(!success) {
        NSLog(@"failed to save forums");
    }
}

-(BOOL)isRefreshSection : (NSIndexPath *)indexPath
{
    if(indexPath.section == [self.forumSections count] + 1) {
        return YES;
    }
    return NO;
}

#pragma mark -
#pragma mark Tree Model Methods

-(void)addForumToSectionTree : (AwfulForum *)forum
{
    AwfulForumSection *section = [[AwfulForumSection alloc] init];
    section.forum = forum;

    if(forum.parentForumID == nil) {
        [section setExpanded:YES];
        [self.forumSections addObject:section];
    } else {
        AwfulForumSection *parent_section = [self getForumSectionFromID:forum.parentForumID];
        if(parent_section.rowIndex != NSNotFound) {
            [section setRowIndex:parent_section.rowIndex + [parent_section.children count]];
        } else {
            [section setRowIndex:[parent_section.children count]];
        }
        [parent_section.children addObject:section];
        
        int ancestors_count = 0;
        while(parent_section != nil) {
            ancestors_count++;
            parent_section = [self getForumSectionFromID:parent_section.forum.parentForumID];
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
    if(path.section == 0) {
        return [self.favorites objectAtIndex:path.row];
    } else {
        AwfulForumSection *section = [self getForumSectionAtIndexPath:path];
        return section.forum;
    }
    return nil;
}

-(AwfulForumSection *)getForumSectionAtIndexPath : (NSIndexPath *)path
{
    if(path.section == 0) {
        AwfulForum *forum = [self.favorites objectAtIndex:path.row];
        return [AwfulForumSection sectionWithForum:forum];
    } else if(path.section == [self.forumSections count] + 1) {
        // refresh button
        return nil;
    }
    
    if(!isLoggedIn()) {
        if(path.section == 1) {
            AwfulForum *goldmine = [[AwfulForum alloc] init];
            goldmine.forumID = @"21";
            goldmine.name = @"Comedy Goldmine";
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
    if(section.forum.parentForumID == nil) {
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
    if(section.forum.parentForumID == nil) {
        return section;
    }
    return [self getRootSectionForSection:[self getForumSectionFromID:section.forum.parentForumID]];
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
    AwfulForum *forum = [self getForumAtIndexPath:indexPath];
    
    AwfulThreadListIpad *detail = [[AwfulThreadListIpad alloc] initWithAwfulForum:forum];
    [self.navigationController pushViewController:detail animated:YES];
}

@end
