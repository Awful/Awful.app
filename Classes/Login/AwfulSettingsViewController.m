//
//  AwfulSettingsViewController.m
//  Awful
//
//  Created by Sean Berry on 3/1/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulSettingsViewController.h"
#import "AwfulUser.h"
#import "AwfulUser+AwfulMethods.h"
#import "AwfulUtil.h"
#import "AwfulLoginController.h"
#import "AwfulNetworkEngine.h"

@interface AwfulSettingsViewController ()

@property (strong) AwfulUser *user;

@end

@implementation AwfulSettingsViewController

typedef enum SettingsSection
{
    LogInLogOutSection,
    ResetDataSection,
    LoadSection,
    StartingTabSection,
    RefreshBookmarksSection,
    SALRSection,
    NumLoggedInSections
} SettingsSection;

static const int NumLoggedOutSections = ResetDataSection + 1;

typedef enum LoggedInRows
{
    UsernameRow,
    LogOutRow,
    NumLoggedInRows
} LoggedInRows;

typedef enum LoggedOutRows
{
    LogInRow,
    NumLoggedOutRows
} LoggedOutRows;

typedef enum ResetDataRows
{
    ResetDataRow,
    NumResetDataRows
} ResetDataRows;

typedef enum LoadRows
{
    LoadAvatarsRow,
    LoadImagesRow,
    LoadReadPostsRow,
    NumLoadRows
} LoadRows;

typedef enum StartingTabRows
{
    StartingTabRow,
    NumStartingTabRows
} StartingTabRows;

typedef enum RefreshBookmarksRows
{
    RefreshBookmarksRow,
    NumRefreshBookmarksRows
} RefreshBookmarksRows;

typedef enum SALRRows
{
    HighlightMentionsRow,
    HighlightOwnQuotesRow,
    NumSALRRows
} SALRRows;

// TODO can we macro this?
static const int MostRowsInSection = 3;

typedef enum CellType
{
    InformationCellType,
    SwitchCellType,
    ChoiceCellType,
    ButtonCellType
} CellType;

typedef struct SectionCellType
{
    int section;
    int cellType[MostRowsInSection];
} SectionCellType;

static const SectionCellType LoggedInCellTypes[] =
{
    { LogInLogOutSection,      { InformationCellType, ButtonCellType }, },
    { ResetDataSection,        { ButtonCellType }, },
    { LoadSection,             { SwitchCellType, SwitchCellType, ChoiceCellType }, },
    { StartingTabSection,      { ChoiceCellType }, },
    { RefreshBookmarksSection, { ChoiceCellType }, },
    { SALRSection,             { SwitchCellType, SwitchCellType }, },
};

static const SectionCellType LoggedOutCellTypes[] =
{
    { LogInLogOutSection, { ButtonCellType }, },
    { ResetDataSection,   { ButtonCellType }, },
};

@synthesize user = _user;

- (void)viewDidLoad
{
    [super viewDidLoad];
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
    return IsLoggedIn() ? NumLoggedInSections : NumLoggedOutSections;
} 

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (IsLoggedIn()) {
        switch (section) {
            case LogInLogOutSection:      return NumLoggedInRows;
            case ResetDataSection:        return NumResetDataRows;
            case LoadSection:             return NumLoadRows;
            case StartingTabSection:      return NumStartingTabRows;
            case RefreshBookmarksSection: return NumRefreshBookmarksRows;
            case SALRSection:             return NumSALRRows;
        }
    } else {
        switch (section) {
            case LogInLogOutSection: return NumLoggedOutRows;
            case ResetDataSection:   return NumResetDataRows;
        }
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString * const Cells[] = { @"Information", @"Switch", @"Choice", @"Button" };
    const SectionCellType *CellTypes = IsLoggedIn() ? LoggedInCellTypes : LoggedOutCellTypes;
    NSString *cellIdentifier = Cells[CellTypes[indexPath.section].cellType[indexPath.row]];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    UILabel *cellLabel = (UILabel *)[cell viewWithTag:0];
    UISwitch *cellSwitch = (UISwitch *)[cell viewWithTag:1];
    
    if (IsLoggedIn()) {
        switch (indexPath.section) {
            case LogInLogOutSection: switch (indexPath.row) {
                case UsernameRow:
                    cell.textLabel.text = @"Logged in";
                    cell.detailTextLabel.text = self.user.userName;
                    break;
                case LogOutRow: cell.textLabel.text = @"Log Out"; break;
            } break;
                
            case ResetDataSection: switch (indexPath.row) {
                case ResetDataRow: cell.textLabel.text = @"Reset Data"; break;
            } break;
            
            case LoadSection: switch (indexPath.row) {
                case LoadAvatarsRow: cellLabel.text = @"Show avatars"; break;
                case LoadImagesRow: cellLabel.text = @"Show images"; break;
                case LoadReadPostsRow:
                    cell.textLabel.text = @"Load read posts";
                    cell.detailTextLabel.text = @"None";
                    break;
            } break;
                
            case StartingTabSection: switch (indexPath.row) {
                case StartingTabRow:
                    cell.textLabel.text = @"Starting tab";
                    cell.detailTextLabel.text = @"Forums";
                    break;
            } break;
                
            case RefreshBookmarksSection: switch (indexPath.row) {
                case RefreshBookmarksRow:
                    cell.textLabel.text = @"Refresh bookmarks";
                    cell.detailTextLabel.text = @"Immediately";
                    break;
            } break;
                
            case SALRSection: switch (indexPath.row) {
                case HighlightMentionsRow: cellLabel.text = @"Highlight mentions"; break;
                case HighlightOwnQuotesRow: cellLabel.text = @"Highlight own quotes"; break;
            } break;
        }
    } else {
        switch (indexPath.section) {
            case LogInLogOutSection: switch (indexPath.row) {
                case LogInRow: cell.textLabel.text = @"Log In"; break;  
            } break;
            
            case ResetDataSection: switch (indexPath.row) {
                case ResetDataRow: cell.textLabel.text = @"Reset Data"; break;
            } break;
        }
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
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
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (section == ResetDataSection) {
        return @"Resetting data clears all cached forums, threads, and posts.";
    }
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
