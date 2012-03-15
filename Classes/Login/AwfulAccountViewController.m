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
#import "AwfulLoginController.h"
#import "AwfulNetworkEngine.h"

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
        
    AwfulUser *user = [AwfulUser currentUser];
    if(user.userName == nil && isLoggedIn()) {
        [self refresh];
    } else {
        self.usernameLabel.text = user.userName;
    }
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
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if([[segue identifier] isEqualToString:@"Login"]) {
        UINavigationController *nav = (UINavigationController *)segue.destinationViewController;
        AwfulLoginController *login = (AwfulLoginController *)nav.topViewController;
        login.accountViewController = self;
    }
}

-(void)refresh
{
    [super refresh];
    [self.networkOperation cancel];
    self.networkOperation = [ApplicationDelegate.awfulNetworkEngine userInfoRequestOnCompletion:^(AwfulUser *user) {
        if(![user.userName isEqualToString:self.usernameLabel.text]) {
            self.usernameLabel.text = user.userName;
            [self.tableView reloadData];
        }
        [self finishedRefreshing];
    } onError:^(NSError *error) {
        [self finishedRefreshing];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Failed" message:[error localizedDescription] delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
        [alert show];
    }];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
    if(isLoggedIn()) {
        return 2;
    }
    return 1;
} 

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if(isLoggedIn()) {
        if(section == 0) {
            return 2;
        }
    } else {
        return 1;
    }
    return 0;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *infoIdent = @"Information";
    static NSString *buttonIdent = @"Button";
    if(isLoggedIn()) {
        if(indexPath.row == 0) {
            UITableViewCell *login_name = [tableView dequeueReusableCellWithIdentifier:infoIdent];
            login_name.textLabel.text = @"Logged in as:";
            AwfulUser *user = [AwfulUser currentUser];
            login_name.detailTextLabel.text = user.userName;
            return login_name;
        } else if(indexPath.row == 1) {
            UITableViewCell *logout = [tableView dequeueReusableCellWithIdentifier:buttonIdent];
            logout.textLabel.text = @"Logout";
            return logout;
        }
    } else {
        UITableViewCell *login = [tableView dequeueReusableCellWithIdentifier:buttonIdent];
        login.textLabel.text = @"Login";
        return login;
    }
    return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(isLoggedIn()) {
        if(indexPath.section == 0 && indexPath.row == 1) {
            
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Log Out Confirm" message:@"Log Out? Are you sure?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Log Out", nil];
            alert.delegate = self;
            [alert show];
            
            [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
        }
    } else {
        if(indexPath.section == 0 && indexPath.row == 0) {
            [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
            [self performSegueWithIdentifier:@"Login" sender:self];
        }
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
        
        AwfulUser *user = [AwfulUser currentUser];
        [user killUser];
        [self.tableView reloadData];
    }
}

@end
