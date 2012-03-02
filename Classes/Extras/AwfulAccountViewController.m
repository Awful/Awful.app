//
//  AwfulAccountViewController.m
//  Awful
//
//  Created by Sean Berry on 3/1/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulAccountViewController.h"
#import "AwfulUser.h"
#import "AwfulUtil.h"

@implementation AwfulAccountViewController

@synthesize usernameLabel = _usernameLabel;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)viewDidUnload
{
    [self setUsernameLabel:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    AwfulUser *user = [[AwfulUser alloc] init];
    [user loadUser];
    self.usernameLabel.text = user.userName;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(indexPath.section == 0 && indexPath.row == 1) {
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Log Out Confirm" message:@"Log Out? Are you sure?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Log Out", nil];
        alert.delegate = self;
        [alert show];
        
        [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    } else if(indexPath.section == 1 && indexPath.row == 0) {
        [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(buttonIndex == 1) {
        NSURL *awful_url = [NSURL URLWithString:@"http://forums.somethingawful.com"];
        NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:awful_url];
        
        for(NSHTTPCookie *cookie in cookies) {
            [[NSHTTPCookieStorage sharedHTTPCookieStorage] deleteCookie:cookie];
        }
        
        AwfulUser *user = [[AwfulUser alloc] init];
        [user killUser];
        
        /*
        NSIndexPath *login_row = [self getIndexPathForLoggedInCell];
        NSIndexPath *logout_row = [NSIndexPath indexPathForRow:1 inSection:0];
        
        [self.tableView beginUpdates];
        [self.tableView
         reloadRowsAtIndexPaths:[NSArray arrayWithObject:login_row] 
         withRowAnimation:UITableViewRowAnimationNone];
        
        [self.tableView 
         deleteRowsAtIndexPaths:[NSArray arrayWithObject:logout_row] 
         withRowAnimation:UITableViewRowAnimationBottom];
        
        [self.tableView endUpdates];*/
    }
}

@end
