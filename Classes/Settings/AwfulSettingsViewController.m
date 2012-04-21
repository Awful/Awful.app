//
//  AwfulSettingsViewController.m
//  Awful
//
//  Created by Sean Berry on 3/1/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulSettingsViewController.h"
#import "AwfulSettings.h"
#import "AwfulUser.h"
#import "AwfulUser+AwfulMethods.h"
#import "AwfulUtil.h"
#import "AwfulLoginController.h"
#import "AwfulNetworkEngine.h"

@interface AwfulSettingsViewController ()

@property (strong) NSArray *sections;

@property (strong) AwfulUser *user;

@end

@implementation AwfulSettingsViewController

@synthesize sections = _sections;

@synthesize user = _user;

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.sections = [[AwfulSettings settings] sections];
    self.user = [AwfulUser currentUser];
    if (self.user.userName == nil && IsLoggedIn()) {
        [self refresh];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"Login"]) {
        UINavigationController *nav = (UINavigationController *)segue.destinationViewController;
        AwfulLoginController *login = (AwfulLoginController *)nav.topViewController;
        login.accountViewController = self;
    }
}

- (void)refresh
{
    [super refresh];
    [self.networkOperation cancel];
    self.networkOperation = [ApplicationDelegate.awfulNetworkEngine userInfoRequestOnCompletion:^(AwfulUser *user) {
        self.user = user;
        [self.tableView reloadData];
        [self finishedRefreshing];
    } onError:^(NSError *error) {
        [self finishedRefreshing];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Failed"
                                                        message:[error localizedDescription]
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    }];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
    // TODO hide appropriate sections when logged in/out
    return self.sections.count;
} 

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // TODO deal with hidden sections
    NSDictionary *settingSection = [self.sections objectAtIndex:section];
    return [[settingSection objectForKey:@"Settings"] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault 
                                      reuseIdentifier:@"cell"];
    }
    
    NSDictionary *settingSection = [self.sections objectAtIndex:indexPath.section];
    NSDictionary *setting = [[settingSection objectForKey:@"Settings"] objectAtIndex:indexPath.row];
    cell.textLabel.text = [setting objectForKey:@"Title"];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    /*
    if (IsLoggedIn()) {
        switch (indexPath.section) {
            case LogInLogOutSection: switch (indexPath.row) {
                case LogOutRow: {
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Log Out"
                                                                    message:@"Are you sure you want to log out?"
                                                                   delegate:self
                                                          cancelButtonTitle:@"Cancel"
                                                          otherButtonTitles:@"Log Out", nil];
                    alert.delegate = self;
                    [alert show];
                } break;
            } break;
                
            case ResetDataSection: switch (indexPath.row) {
                case ResetDataRow: [ApplicationDelegate resetDataStore]; break;
            }
        }
    } else {
        switch (indexPath.section) {
            case LogInLogOutSection: switch (indexPath.row) {
                case LogInRow:
                    [self performSegueWithIdentifier:@"Login" sender:self];
                    break;
            } break;
                
            case ResetDataSection: switch (indexPath.row) {
                case ResetDataRow: [ApplicationDelegate resetDataStore]; break;
            } break;
        }
    }
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
     */
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    /*
    if (section == ResetDataSection) {
        return @"Resetting data clears all cached forums, threads, and posts.";
    }
     */
    return nil;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex != 1)
        return;
    
    NSURL *awful_url = [NSURL URLWithString:@"http://forums.somethingawful.com"];
    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:awful_url];
    
    for (NSHTTPCookie *cookie in cookies) {
        [[NSHTTPCookieStorage sharedHTTPCookieStorage] deleteCookie:cookie];
    }
    
    AwfulUser *user = [AwfulUser currentUser];
    [ApplicationDelegate.managedObjectContext deleteObject:user];
    [ApplicationDelegate saveContext];
    [self.tableView reloadData];
}

- (IBAction)resetData:(id)sender 
{
    [ApplicationDelegate resetDataStore];
}

@end
