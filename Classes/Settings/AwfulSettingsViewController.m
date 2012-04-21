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
#import "AwfulSettingsChoiceViewController.h"

@interface AwfulSettingsViewController ()

@property (strong) NSArray *sections;

@property (strong) AwfulUser *user;

@property (strong) NSMutableArray *switches;

@end

@implementation AwfulSettingsViewController

@synthesize sections = _sections;

@synthesize user = _user;

@synthesize switches = _switches;

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.switches = [NSMutableArray new];
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
    if (IsLoggedIn()) {
        return self.sections.count - 1;
    } else {
        return 2;
    }
} 

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    section = [self fudgedSectionForSection:section];
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
    indexPath = [self fudgedIndexPathForIndexPath:indexPath];
    
    // Grab the cell we need.
    
    NSDictionary *setting = [self settingForIndexPath:indexPath];
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
    
    // Set it up as we like it.
    
    cell.textLabel.text = [setting objectForKey:@"Title"];
    
    if (settingType == ImmutableSetting) {
        // This only works because there's one immutable setting here.
        cell.detailTextLabel.text = self.user.userName;
    }
    
    NSString *key = [setting objectForKey:@"Key"];
    id valueForSetting = key ? [[NSUserDefaults standardUserDefaults] objectForKey:key] : nil;
    
    if (settingType == OnOffSetting) {
        NSUInteger tag = [self.switches indexOfObject:indexPath];
        if (tag == NSNotFound) {
            tag = self.switches.count;
            [self.switches addObject:indexPath];
        }
        UISwitch *switchView = [[UISwitch alloc] initWithFrame:CGRectZero];
        switchView.on = [valueForSetting boolValue];
        [switchView addTarget:self
                       action:@selector(hitSwitch:)
             forControlEvents:UIControlEventValueChanged];
        switchView.tag = tag;
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
    
    return cell;
}

- (void)hitSwitch:(UISwitch *)switchView
{
    NSIndexPath *indexPath = [self.switches objectAtIndex:switchView.tag];
    NSDictionary *setting = [self settingForIndexPath:indexPath];
    NSString *key = [setting objectForKey:@"Key"];
    [[NSUserDefaults standardUserDefaults] setBool:switchView.on forKey:key];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    indexPath = [self fudgedIndexPathForIndexPath:indexPath];
    NSDictionary *setting = [self settingForIndexPath:indexPath];
    NSString *action = [setting objectForKey:@"Action"];
    if ([action isEqualToString:@"LogOut"]) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Log Out"
                                                        message:@"Are you sure you want to log out?"
                                                       delegate:self
                                              cancelButtonTitle:@"Cancel"
                                              otherButtonTitles:@"Log Out", nil];
        alert.delegate = self;
        [alert show];
    } else if ([action isEqualToString:@"LogIn"]) {
        [self performSegueWithIdentifier:@"Login" sender:self];
    } else if ([action isEqualToString:@"ResetData"]) {
        [ApplicationDelegate resetDataStore];
    } else {
        NSString *key = [setting objectForKey:@"Key"];
        id selectedValue = [[NSUserDefaults standardUserDefaults] objectForKey:key];
        AwfulSettingsChoiceViewController *choiceViewController = [[AwfulSettingsChoiceViewController alloc] initWithSetting:setting selectedValue:selectedValue];
        choiceViewController.settingsViewController = self;
        [self.navigationController pushViewController:choiceViewController animated:YES];
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)didMakeChoice:(AwfulSettingsChoiceViewController *)choiceViewController
{
    NSString *key = [choiceViewController.setting objectForKey:@"Key"];
    [[NSUserDefaults standardUserDefaults] setObject:choiceViewController.selectedValue
                                              forKey:key];
    [self.tableView reloadData];
}

- (NSIndexPath *)fudgedIndexPathForIndexPath:(NSIndexPath *)indexPath
{
    return [NSIndexPath indexPathForRow:indexPath.row
                              inSection:[self fudgedSectionForSection:indexPath.section]];
}

- (NSInteger)fudgedSectionForSection:(NSInteger)section
{
    // Skip either LogInSection or LogOutSection as needed.
    if (IsLoggedIn() || section > 0) {
        return section + 1;
    } else {
        return section;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    section = [self fudgedSectionForSection:section];
    NSDictionary *settingSection = [self.sections objectAtIndex:section];
    return [settingSection objectForKey:@"Title"];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    section = [self fudgedSectionForSection:section];
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

- (NSDictionary *)settingForIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *settingSection = [self.sections objectAtIndex:indexPath.section];
    NSArray *listOfSettings = [settingSection objectForKey:@"Settings"];
    return [listOfSettings objectAtIndex:indexPath.row];

}

@end
