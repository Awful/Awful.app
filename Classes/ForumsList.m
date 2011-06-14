//
//  ForumsList.m
//  Awful
//
//  Created by Sean Berry on 7/27/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "ForumsList.h"
#import "FMDatabase.h"
#import "AwfulForum.h"
#import "AwfulThreadList.h"
#import "AwfulAppDelegate.h"
#import "AwfulNavController.h"
#import "AwfulUtil.h"
#import "Stylin.h"
#import "AwfulConfig.h"

@implementation ForumsList

#pragma mark -
#pragma mark Initialization

@synthesize favorites;

- (id)initWithStyle:(UITableViewStyle)style {
    // Override initWithStyle: if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
    if ((self = [super initWithStyle:style])) {
        NSMutableArray *chosen = [AwfulUtil newChosenForums];
        favorites = [chosen retain];
        [chosen release];
        
        sectionTitles = [[NSMutableArray alloc] init];
        sectionArrays = [[NSMutableArray alloc] init];
        
        FMDatabase *db = [AwfulUtil getDB];
        [db open];
        
        FMResultSet *res = [db executeQuery:@"SELECT section_name, id FROM forumSections"];
        
        if([db hadError]) {
            NSLog(@"%@", [db lastErrorMessage]);
        }
        
        while([res next]) {
            NSString *name = [res stringForColumn:@"section_name"];
            NSString *section_id = [res stringForColumn:@"id"];
            [sectionTitles addObject:name];
            
            FMResultSet *forums_res = [db executeQuery:@"SELECT name, forum_id FROM forums WHERE section_id = ?", section_id];
            
            if([db hadError]) {
                NSLog(@"%@", [db lastErrorMessage]);
            }
            
            NSMutableArray *section_forums = [[NSMutableArray alloc] init];
            
            while([forums_res next]) {
                NSString *forum_name = [forums_res stringForColumn:@"name"];
                NSString *fid = [forums_res stringForColumn:@"forum_id"];
                if([fid isEqualToString:@"177"]) {
                    forum_name = @"Punchsport Pagoda";
                }
                AwfulForum *f = [[AwfulForum alloc] init];
                [f setName:forum_name];
                [f setForumID:fid];
                
                if([forum_name isEqualToString:@"Comedy Goldmine"]) {
                    goldmine = f;
                }
                
                [section_forums addObject:f];
                [f release];
            }
            
            if([name isEqualToString:@"Games"]) {
                AwfulForum *rift = [[AwfulForum alloc] init];
                [rift setName:@"Rift: Goon Squad HQ"];
                [rift setForumID:@"254"];
                [section_forums addObject:rift];
                [rift release];
            }
            
            [sectionArrays addObject:section_forums];
            
            [section_forums release];
            [forums_res close];
        }
        
        [res close];
        [db close];
        
        AwfulNavController *nav = getnav();
        NSString *awful_str = @"Awful    ";
        if(![nav isLoggedIn]) {
            awful_str = @"Awful ";
        }
        UIView *custom_title = [Stylin newCustomNavbarTitleWithText:awful_str];
        
        UITapGestureRecognizer *top_tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(slideToTop)];
        [custom_title addGestureRecognizer:top_tap];
        [top_tap release];
        
        [self.navigationItem setTitleView:custom_title];
        [custom_title release];
        
    }
    return self;
}

- (void)dealloc {
    [favorites release];
    [sectionArrays release];
    [sectionTitles release];
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
    for(NSMutableArray *ar in sectionArrays) {
        for(AwfulForum *f in ar) {
            if([f.forumID isEqualToString:forum_id]) {
                [favorites addObject:f];
                [AwfulUtil saveChosenForums:favorites];
                [self.tableView reloadData];
            }
        }
    }
}

-(void)removeFavorite : (UIButton *)sender
{
    NSString *forum_id = [sender titleForState:UIControlStateDisabled];
    
    AwfulForum *fav = nil;
    for(AwfulForum *f in favorites) {
        if([f.forumID isEqualToString:forum_id]) {
            fav = f;
        }
    }
    
    [favorites removeObject:fav];
    [AwfulUtil saveChosenForums:favorites];
    [self.tableView reloadData];
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
    return [sectionTitles count] + 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    AwfulAppDelegate *del = (AwfulAppDelegate *)[[UIApplication sharedApplication] delegate];
    AwfulNavController *nav = del.navController;
    BOOL logged_in = [nav isLoggedIn];
    if(!logged_in) {
        return 1;
    }
    
    if(section == 1) {
        return [favorites count];
    } else if(section == 0) {
        return 0;
    }
    
    return [[sectionArrays objectAtIndex:section-2] count];
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
        float offwhite = 241.0/255;
        cell.backgroundColor = [UIColor colorWithRed:offwhite green:offwhite blue:offwhite alpha:1.0];
        
        UIButton *star = [UIButton buttonWithType:UIButtonTypeCustom];
        star.frame = CGRectMake(0, 0, 50, 50);
        cell.accessoryView = star;
        cell.textLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:14.0];
        cell.textLabel.numberOfLines = 2;
    }
    
    // Configure the cell...
    AwfulForum *aw = nil;
    AwfulAppDelegate *del = (AwfulAppDelegate *)[[UIApplication sharedApplication] delegate];
    AwfulNavController *nav = del.navController;
    BOOL logged_in = [nav isLoggedIn];
    
    UIButton *fav = (UIButton *)cell.accessoryView;
    [fav removeTarget:self action:@selector(removeFavorite:) forControlEvents:UIControlEventTouchUpInside];
    [fav removeTarget:self action:@selector(makeFavorite:) forControlEvents:UIControlEventTouchUpInside]; 
    
    if(indexPath.section == 0 && logged_in) {
        return cell;
    }
    
    if(indexPath.section == 1 && logged_in) {
        aw = [favorites objectAtIndex:indexPath.row];
        [fav setImage:[UIImage imageNamed:@"star_on.png"] forState:UIControlStateNormal];
        [fav addTarget:self action:@selector(removeFavorite:) forControlEvents:UIControlEventTouchUpInside];
    } else if(logged_in && indexPath.section > 1) {
        aw = [[sectionArrays objectAtIndex:indexPath.section-2] objectAtIndex:indexPath.row];
        BOOL winner = NO;
        for(AwfulForum *f in favorites) {
            if([f.forumID isEqualToString:aw.forumID]) {
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
    }

    if(!logged_in) {
        aw = goldmine;
    }
    
    cell.textLabel.text = aw.name;
    [fav setTitle:aw.forumID forState:UIControlStateDisabled];
    
    return cell;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    AwfulNavController *nav = getnav();
    BOOL logged_in = [nav isLoggedIn];
    NSString *str = nil;
    if(section == 0 && logged_in) {
        if(nav.user.userName == nil) {
            str = @"WELCOME TO THE AWFUL APP";
        } else {
            str = [NSString stringWithFormat:@"Logged in as %@", nav.user.userName];
        }
    } else if(section == 1 || !logged_in) {
        str = @"Favorites";
    } else {
        str = [sectionTitles objectAtIndex:section - 2];
    }
    
    UIFont *f = [UIFont fontWithName:@"Helvetica-Bold" size:18.0];
    if(section == 0 && logged_in) {
        f = [UIFont fontWithName:@"Helvetica" size:12.0];
    }
    
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
        return 20;
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
        [awfulForums removeObjectAtIndex:indexPath.row];
        [AwfulUtil saveChosenForums:awfulForums];
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:YES];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*

// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
    
    AwfulForum *aw = [[awfulForums objectAtIndex:fromIndexPath.row] retain];
    [awfulForums removeObjectAtIndex:fromIndexPath.row];
    [awfulForums insertObject:aw atIndex:toIndexPath.row];
    [AwfulUtil saveChosenForums:awfulForums];
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
        forum = goldmine;
    } else {
        if(indexPath.section == 1) {
            forum = [favorites objectAtIndex:indexPath.row];
        } else {
            forum = [[sectionArrays objectAtIndex:indexPath.section-2] objectAtIndex:indexPath.row];
        }
    }
    
    AwfulThreadList *detail = [[AwfulThreadList alloc] initWithAwfulForum:forum];
    [nav loadForum:detail];
    [detail release];
}

-(void)slideToTop
{
    /*int sec = 1;
    if([favorites count] == 0) {
        sec = 2;
    }
    
    NSIndexPath *path = [NSIndexPath indexPathForRow:0 inSection:sec];
    [self.tableView scrollToRowAtIndexPath:path atScrollPosition:UITableViewScrollPositionTop animated:YES];*/
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


@end

