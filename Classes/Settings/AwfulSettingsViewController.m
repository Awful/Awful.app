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

typedef enum SettingType
{
    ImmutableSetting,
    OnOffSetting,
    ChoiceSetting,
    ButtonSetting,
} SettingType;

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *settingSection = [self.sections objectAtIndex:indexPath.section];
    NSDictionary *setting = [[settingSection objectForKey:@"Settings"] objectAtIndex:indexPath.row];
    SettingType settingType = ImmutableSetting;
    if ([[setting objectForKey:@"Type"] isEqual:@"Switch"]) {
        settingType = OnOffSetting;
    } else if ([setting objectForKey:@"Choices"]) {
        settingType = ChoiceSetting;
    } else if ([setting objectForKey:@"Action"]) {
        settingType = ButtonSetting;
    }
    NSString *identifier = @"Value1";
    UITableViewCellStyle style = UITableViewCellStyleValue1;
    if (settingType == OnOffSetting || settingType == ButtonSetting) {
        identifier = @"Default";
        style = UITableViewCellStyleDefault;
    }
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell)
    {
        cell = [[UITableViewCell alloc] initWithStyle:style 
                                      reuseIdentifier:identifier];
    }
    
    if (settingType == ImmutableSetting) {
        // This only works because there's one immutable setting here.
        // TODO ask delegate!
        cell.detailTextLabel.text = self.user.userName;
    }
    
    NSString *key = [setting objectForKey:@"Key"];
    id valueForSetting = key ? [[NSUserDefaults standardUserDefaults] objectForKey:key] : nil;
    
    if (settingType == OnOffSetting) {
        // TODO hook up switch action
        UISwitch *switchView = [[UISwitch alloc] initWithFrame:CGRectZero];
        switchView.on = [valueForSetting boolValue];
        cell.accessoryView = switchView;
    } else {
        cell.accessoryView = nil;
    }
    
    if (settingType == ChoiceSetting) {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        for (NSDictionary *choice in [setting objectForKey:@"Choices"]) {
            if ([[choice objectForKey:@"Value"] isEqual:valueForSetting]) {
                cell.detailTextLabel.text = [choice objectForKey:@"Title"];
                break;
            }
        }
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    if (settingType == ChoiceSetting || settingType == ButtonSetting) {
         cell.selectionStyle = UITableViewCellSelectionStyleBlue;   
    } else {
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    
    if (settingType == ButtonSetting) {
        cell.textLabel.textAlignment = UITextAlignmentCenter;
    } else {
        cell.textLabel.textAlignment = UITextAlignmentLeft;
    }
    
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

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    NSDictionary *settingSection = [self.sections objectAtIndex:section];
    return [settingSection objectForKey:@"Title"];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    NSDictionary *settingSection = [self.sections objectAtIndex:section];
    return [settingSection objectForKey:@"Explanation"];
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
