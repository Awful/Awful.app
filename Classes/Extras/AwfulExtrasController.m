//
//  AwfulExtrasController.m
//  Awful
//
//  Created by Regular Berry on 6/21/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulExtrasController.h"
#import "AwfulLoginController.h"
#import "AwfulUser.h"
#import "AwfulNavigator.h"
#import "AwfulHelpController.h"
#import "AwfulAppThreadRequest.h"

static NSString *CELL_IDENT_BUTTON = @"ButtonCell";
static NSString *CELL_IDENT_LABEL = @"LabelCell";

@implementation AwfulLabelCell

@synthesize label = _label;

-(void)dealloc
{
    [_label release];
    [super dealloc];
}

@end

@implementation AwfulButtonCell

@synthesize button = _button;
@synthesize buttonTarget = _buttonTarget;

-(void)setSelector : (SEL)selector withText : (NSString *)text
{
    if(self.buttonTarget == nil) {
        return;
    }
    
    NSArray *actions = [self.button actionsForTarget:self.buttonTarget forControlEvent:UIControlEventTouchUpInside];
    for(NSString *selector_str in actions) {
        SEL old_selector = NSSelectorFromString(selector_str);
        [self.button removeTarget:self.buttonTarget action:old_selector forControlEvents:UIControlEventTouchUpInside];
    }
    [self.button addTarget:self.buttonTarget action:selector forControlEvents:UIControlEventTouchUpInside];
    [self.button setTitle:text forState:UIControlStateNormal];
}

-(void)dealloc
{
    [_button release];
    [super dealloc];
}

@end

@implementation AwfulExtrasController

@synthesize buttonCell = _buttonCell;
@synthesize labelCell = _labelCell;

- (id)init
{
    if((self=[super initWithStyle:UITableViewStyleGrouped])) {
        self.title = @"Awful App";
        self.tabBarItem.image = [UIImage imageNamed:@"dotdotdot-clear.png"];
        self.tabBarItem.title = @"More";
    }
    return self;
}

- (void)dealloc
{
    [_buttonCell release];
    [_labelCell release];
    [super dealloc];
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    //self.tableView.separatorColor = [UIColor colorWithRed:0.75 green:0.75 blue:0.75 alpha:1.0];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.backgroundColor = [UIColor colorWithRed:0 green:0.4 blue:0.6 alpha:1.0];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    
    self.buttonCell = nil;
    self.labelCell = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return YES;
    }
    // Return YES for supported orientations
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    if(isLoggedIn() && section == 0) {
        return 2;
    }
    if(section == 1 || section == 2) {
        return 1;
    }
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    NSString *ident = [self cellIdentifierForIndexPath:indexPath];
    if(ident == nil) {
        NSLog(@"couldn't find cell type for index path %@", indexPath);
    }
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:ident];
    if (cell == nil) {
        [[NSBundle mainBundle] loadNibNamed:@"AwfulExtrasCells" owner:self options:nil];
        if(ident == CELL_IDENT_BUTTON) {
            [self.buttonCell setButtonTarget:self];
            cell = self.buttonCell;
        } else if(ident == CELL_IDENT_LABEL) {
            AwfulNavigator *nav = getNavigator();
            [self.labelCell.label setText:[NSString stringWithFormat:@"Logged in as: %@", nav.user.userName]];
            cell = self.labelCell;
        }
        
    }
    
    if(ident == CELL_IDENT_BUTTON) {
        AwfulButtonCell *button_cell = (AwfulButtonCell *)cell;
        if(indexPath.section == 0) {
            if(indexPath.row == 0) {
                [button_cell setSelector:@selector(tappedLogin) withText:@"Login"];
            } else if(indexPath.row == 1) {
                [button_cell setSelector:@selector(tappedLogout) withText:@"Logout"];
            }
        } else if(indexPath.section == 1) {
            [button_cell setSelector:@selector(tappedHelp) withText:@"Quick FAQ"];
        } else if(indexPath.section == 2) {
            [button_cell setSelector:@selector(tappedAwfulAppThread) withText:@"Awful App Thread"];
        }
    }
    
    return cell;
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

#pragma mark - User Name Loading

-(void)reloadUserName
{
    NSIndexPath *login_path = [self getIndexPathForLoggedInCell];
    NSIndexPath *logout_path = [NSIndexPath indexPathForRow:1 inSection:0];
    
    [self.tableView beginUpdates];
    
    [self.tableView 
     reloadRowsAtIndexPaths:[NSArray arrayWithObject:login_path] 
     withRowAnimation:UITableViewRowAnimationFade];
    
    [self.tableView
     insertRowsAtIndexPaths:[NSArray arrayWithObject:logout_path] 
     withRowAnimation:UITableViewRowAnimationTop];
    
    [self.tableView endUpdates];
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Navigation logic may go here. Create and push another view controller.
    /*
     <#DetailViewController#> *detailViewController = [[<#DetailViewController#> alloc] initWithNibName:@"<#Nib name#>" bundle:nil];
     // ...
     // Pass the selected object to the new view controller.
     [self.navigationController pushViewController:detailViewController animated:YES];
     [detailViewController release];
     */
}

#pragma mark - Login

-(void)tappedLogin
{
    AwfulLoginController *login = [[AwfulLoginController alloc] init];
    [self.navigationController pushViewController:login animated:YES];
    [login release];
}

-(void)tappedLogout
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Log Out Confirm" message:@"Log Out? Are you sure?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Log Out", nil];
    alert.delegate = self;
    [alert show];
    [alert release];
}

-(void)tappedHelp
{
    AwfulHelpController *help = [[AwfulHelpController alloc] init];
    [self.navigationController pushViewController:help animated:YES];
    [help release];
}

-(void)tappedAwfulAppThread
{
    AwfulAppThreadRequest *app = [[AwfulAppThreadRequest alloc] initCustom];
    loadRequestAndWait(app);
    [app release];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(buttonIndex == 1) {
        NSURL *awful_url = [NSURL URLWithString:@"http://forums.somethingawful.com"];
        NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:awful_url];
        
        for(NSHTTPCookie *cookie in cookies) {
            [[NSHTTPCookieStorage sharedHTTPCookieStorage] deleteCookie:cookie];
        }
        
        AwfulNavigator *nav = getNavigator();
        [nav.user killUser];
        
        self.navigationItem.rightBarButtonItem = nil;
        
        NSIndexPath *login_row = [self getIndexPathForLoggedInCell];
        NSIndexPath *logout_row = [NSIndexPath indexPathForRow:1 inSection:0];
        
        [self.tableView beginUpdates];
        [self.tableView
            reloadRowsAtIndexPaths:[NSArray arrayWithObject:login_row] 
            withRowAnimation:UITableViewRowAnimationNone];
        
        [self.tableView 
            deleteRowsAtIndexPaths:[NSArray arrayWithObject:logout_row] 
            withRowAnimation:UITableViewRowAnimationBottom];
        
        [self.tableView endUpdates];
    }
}
       
#pragma mark - Row Construction Helpers

-(NSIndexPath *)getIndexPathForLoggedInCell
{
    return [NSIndexPath indexPathForRow:0 inSection:0];
}

-(NSString *)cellIdentifierForIndexPath : (NSIndexPath *)indexPath
{
    NSIndexPath *login = [self getIndexPathForLoggedInCell];
    if(login.section == indexPath.section && login.row == indexPath.row) {
        if(isLoggedIn()) {
            return CELL_IDENT_LABEL;
        } else {
            return CELL_IDENT_BUTTON;
        }
    }
    if(indexPath.section == 0 && indexPath.row == 1) {
        return CELL_IDENT_BUTTON;
    }
    
    if(indexPath.section == 1 || indexPath.section == 2) {
        return CELL_IDENT_BUTTON;
    }
    
    return nil;
}

@end
