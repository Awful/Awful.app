//
//  AwfulForumsList.m
//  Awful
//
//  Created by Sean Berry on 7/27/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulForumsList.h"
#import "FMDatabase.h"
#import "AwfulForum.h"
#import "AwfulThreadList.h"
#import "AwfulAppDelegate.h"
#import "AwfulNavController.h"
#import "AwfulUtil.h"
#import "Stylin.h"
#import "AwfulConfig.h"
#import "AwfulForumListRefreshRequest.h"
#import "AwfulForumCell.h"

#define SECTION_INDEX_OFFSET 1

@implementation AwfulForumSection

@synthesize forum = _forum;
@synthesize children = _children;
@synthesize expanded = _expanded;
@synthesize rowIndex = _rowIndex;
@synthesize totalAncestors = _totalAncestors;

-(id)init
{
    _forum = nil;
    _children = [[NSMutableArray alloc] init];
    _expanded = NO;
    _rowIndex = NSNotFound;
    _totalAncestors = 0;
    return self;
}

-(void)dealloc
{
    [_children release];
    [super dealloc];
}

@end

@implementation AwfulForumsList

#pragma mark -
#pragma mark Initialization

@synthesize favorites = _favorites;
@synthesize forums = _forums;
@synthesize forumSections = _forumSections;
@synthesize goldmine = _goldmine;
@synthesize forumCell = _forumCell;

- (id)initWithStyle:(UITableViewStyle)style {
    // Override initWithStyle: if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
    if ((self = [super initWithStyle:style])) {
        NSMutableArray *chosen = [AwfulUtil newChosenForums];
        _favorites = [chosen retain];
        [chosen release];
        
        _forums = [[NSMutableArray alloc] init];
        _forumSections = [[NSMutableArray alloc] init];
                
                /*if([forum_name isEqualToString:@"Comedy Goldmine"]) {
                    _goldmine = f;
                }*/
                  
        AwfulNavController *nav = getnav();
        NSString *awful_str = @"Awful    ";
        if(![nav isLoggedIn]) {
            awful_str = @"Awful ";
        }
        [self.navigationItem setTitle:awful_str];
        
    }
    return self;
}

- (void)dealloc {
    [_favorites release];
    [_forums release];
    [_forumSections release];
    [super dealloc];
}

#pragma mark -
#pragma mark View lifecycle


- (void)viewDidLoad {
    [super viewDidLoad];
    
    UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(hitDone)];
    self.navigationItem.rightBarButtonItem = done;
    [done release];
    
    [self updateSignedIn];
    
    self.tableView.separatorColor = [UIColor colorWithRed:0.75 green:0.75 blue:0.75 alpha:1.0];
    self.tableView.backgroundColor = [UIColor colorWithRed:0 green:0.4 blue:0.6 alpha:1.0];
    [self grabFreshList];
}

-(void)hitDone
{
    AwfulNavController *nav = getnav();
    [nav dismissModalViewControllerAnimated:YES];
}

-(void)updateSignedIn
{
    AwfulNavController *nav = getnav();
    [nav.user loadUser];

    UIBarButtonItem *sign;
    BOOL logged_in = [nav isLoggedIn];
    if(logged_in) {
        sign = [[UIBarButtonItem alloc] initWithTitle:@"Logout" style:UIBarButtonItemStyleDone target:self action:@selector(signOut)];
    } else {
        sign = [[UIBarButtonItem alloc] initWithTitle:@"Login" style:UIBarButtonItemStyleDone target:nav action:@selector(showLogin)];
    }
    
    self.navigationItem.leftBarButtonItem = sign;
    [sign release];
}

-(void)viewWillAppear:(BOOL)animated
{
    NSMutableArray *chosen = [AwfulUtil newChosenForums];
    [self setFavorites:chosen];
    [chosen release];
    [self.tableView reloadData];
}

-(void)signOut
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Log Out Confirm" message:@"Log Out? Are you sure?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Log Out", nil];
    alert.delegate = self;
    [alert show];
    [alert release];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(buttonIndex == 1) {
        NSURL *awful_url = [NSURL URLWithString:@"http://forums.somethingawful.com"];
        NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:awful_url];
        
        for(NSHTTPCookie *cookie in cookies) {
            [[NSHTTPCookieStorage sharedHTTPCookieStorage] deleteCookie:cookie];
        }
        
        AwfulNavController *nav = getnav();
        [nav.user killUser];
        
        AwfulAppDelegate *del = (AwfulAppDelegate *)[[UIApplication sharedApplication] delegate];
        [del disableCache];
        self.navigationItem.rightBarButtonItem = nil;
        [self.tableView reloadData];
        
        [self updateSignedIn];
    }
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

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    
    if([AwfulConfig allowRotation:interfaceOrientation]) {
        AwfulNavController *nav = getnav();
        [self setToolbarItems:[nav getToolbarItemsForOrientation:interfaceOrientation]];
        return YES;
    }
    return NO;
}

-(void)makeFavorite : (UIButton *)sender
{
    NSString *forum_id = [sender titleForState:UIControlStateDisabled];
    AwfulForumSection *section = [self getForumSectionFromID:forum_id];
    if(section != nil) {
        [self.favorites addObject:section.forum];
        [AwfulUtil saveChosenForums:self.favorites];
        NSArray *insert = [NSArray arrayWithObject:[NSIndexPath indexPathForRow:[self.favorites count]-1 inSection:0]];
        [self.tableView insertRowsAtIndexPaths:insert withRowAnimation:UITableViewRowAnimationTop];
    }
}

-(void)removeFavorite : (UIButton *)sender
{
    NSString *forum_id = [sender titleForState:UIControlStateDisabled];
    
    AwfulForum *fav = nil;
    for(AwfulForum *f in self.favorites) {
        if([f.forumID isEqualToString:forum_id]) {
            fav = f;
        }
    }
    
    [self.favorites removeObject:fav];
    [AwfulUtil saveChosenForums:self.favorites];
    NSArray *remove = [NSArray arrayWithObject:[NSIndexPath indexPathForRow:[self.favorites count] inSection:0]];
    [self.tableView deleteRowsAtIndexPaths:remove withRowAnimation:UITableViewRowAnimationFade];
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {

    AwfulAppDelegate *del = (AwfulAppDelegate *)[[UIApplication sharedApplication] delegate];
    AwfulNavController *nav = del.navController;
    BOOL logged_in = [nav isLoggedIn];
    if(!logged_in) {
        return 1;
    }    
    
    // Return the number of sections.
    return [self.forumSections count] + SECTION_INDEX_OFFSET;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    AwfulAppDelegate *del = (AwfulAppDelegate *)[[UIApplication sharedApplication] delegate];
    AwfulNavController *nav = del.navController;
    BOOL logged_in = [nav isLoggedIn];
    if(!logged_in) {
        return 1;
    }
    
    if(section == 0) {
        return [self.favorites count];
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
    
    static NSString *CellIdentifier = @"Cell";
    
    AwfulForumCell *cell = (AwfulForumCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        [[NSBundle mainBundle] loadNibNamed:@"AwfulForumCell" owner:self options:nil];
        cell = self.forumCell;
        [cell setDelegate:self];
        self.forumCell = nil;
    }
    
    // Configure the cell...
    AwfulNavController *nav = getnav();
    BOOL logged_in = [nav isLoggedIn];
    
    /*UIButton *fav = (UIButton *)cell.star;
    [fav removeTarget:self action:@selector(removeFavorite:) forControlEvents:UIControlEventTouchUpInside];
    [fav removeTarget:self action:@selector(makeFavorite:) forControlEvents:UIControlEventTouchUpInside]; */
    
    AwfulForum *forum = nil;
    
    if(logged_in) {
        forum = [self getForumAtIndexPath:indexPath];
    
        /*if(indexPath.section == 0) {
            [fav setImage:[UIImage imageNamed:@"star_on.png"] forState:UIControlStateNormal];
            [fav addTarget:self action:@selector(removeFavorite:) forControlEvents:UIControlEventTouchUpInside];
        } else {
            BOOL winner = NO;
            for(AwfulForum *f in self.favorites) {
                if([f.forumID isEqualToString:forum.forumID]) {
                    winner = YES;
                }
            }
            if(winner) {
                [fav setImage:[UIImage imageNamed:@"star_on.png"] forState:UIControlStateNormal];
                [fav addTarget:self action:@selector(removeFavorite:) forControlEvents:UIControlEventTouchUpInside];
            } else {
                [fav setImage:[UIImage imageNamed:@"star_off.png"] forState:UIControlStateNormal];
                [fav addTarget:self action:@selector(makeFavorite:) forControlEvents:UIControlEventTouchUpInside];
            }
        }*/
    } else {
        forum = self.goldmine;
    }
    
    AwfulForumSection *section = [self getForumSectionAtIndexPath:indexPath];
    [cell setSection:section];
    
    //[cell.title setText:forum.name];
    //cell.textLabel.text = forum.name;
    //[fav setTitle:forum.forumID forState:UIControlStateDisabled];
    
    return cell;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    NSString *str = nil;

    if(section == 0) {
        str = @"Favorites";
    } else {
        str = [[[self.forumSections objectAtIndex:section-SECTION_INDEX_OFFSET] forum] name];
    }
    
    AwfulNavController *nav = getnav();
    BOOL logged_in = [nav isLoggedIn];
    
    if(!logged_in) {
        str = @"Not Logged In";
    }
    
    UIFont *f = [UIFont fontWithName:@"Helvetica-Bold" size:18.0];
    
    UIView *v = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 250, 30)] autorelease];
    UILabel *forum_label = [[UILabel alloc] initWithFrame:CGRectMake(12, 0, 200, 30)];
    forum_label.font = f;
    forum_label.text = str;
    forum_label.textColor = [UIColor whiteColor];
    forum_label.backgroundColor = [UIColor clearColor];
    
    [v addSubview:forum_label];
    [forum_label release];
    return v;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    AwfulNavController *nav = getnav();
    if(section == 0 && [nav isLoggedIn]) {
        //return 20;
    }
    return 40;
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    
    
    
    return YES;
}
*/


/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*

// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
    
}*/



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

    AwfulForum *forum = nil;
    AwfulNavController *nav = getnav();
    
    BOOL logged_in = [nav isLoggedIn];
    
    if(!logged_in) {
        forum = self.goldmine;
    } else {
        if(indexPath.section == 0) {
            forum = [self.favorites objectAtIndex:indexPath.row];
        } else {
            AwfulForumSection *section = [self getForumSectionAtIndexPath:indexPath];
            forum = section.forum;
        }
    }
    
    AwfulThreadList *detail = [[AwfulThreadList alloc] initWithAwfulForum:forum];
    [nav loadForum:detail];
    [detail release];
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
#pragma mark Misc Methods

-(void)toggleForumSection : (AwfulForumSection *)section
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

-(void)grabFreshList
{
    AwfulForumListRefreshRequest *req = [[AwfulForumListRefreshRequest alloc] initWithForumsList:self];
    AwfulNavController *nav = getnav();
    [nav loadRequest:req];
    [req release];
}

-(void)setForums:(NSMutableArray *)forums
{
    if(forums != _forums) {
        [_forums release];
        _forums = [forums retain];
        
        [self.forumSections removeAllObjects];
        for(AwfulForum *forum in _forums) {
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
    [section setForum:forum];

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
    [section release];
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

