//  AwfulSettingsViewController.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulSettingsViewController.h"
#import "AwfulAlertView.h"
#import "AwfulAppDelegate.h"
#import "AwfulExpandingSplitViewController.h"
#import "AwfulHTTPClient.h"
#import "AwfulInstapaperLogInController.h"
#import "AwfulLoginController.h"
#import "AwfulModels.h"
#import "AwfulPostsViewController.h"
#import "AwfulSettings.h"
#import "AwfulSettingsChoiceViewController.h"
#import "InstapaperAPIClient.h"
#import "NSManagedObject+Awful.h"
#import <PocketAPI/PocketAPI.h>
#import <SVProgressHUD/SVProgressHUD.h>
#import "UIViewController+NavigationEnclosure.h"

@interface AwfulSettingsViewController () <AwfulInstapaperLogInControllerDelegate>

@property (strong, nonatomic) NSArray *sections;
@property (strong, nonatomic) NSMutableArray *switches;
@property (strong, nonatomic) NSMutableArray *steppers;

@end


@implementation AwfulSettingsViewController

- (id)init
{
    if (!(self = [super initWithStyle:UITableViewStyleGrouped])) return nil;
    self.title = @"Settings";
    self.tabBarItem.image = [UIImage imageNamed:@"cog.png"];
    return self;
}

#pragma mark - Settings predicates

- (BOOL)isLoggedInToInstapaper
{
    return !![AwfulSettings settings].instapaperUsername;
}

- (BOOL)isLoggedInToPocket
{
    return [PocketAPI sharedAPI].isLoggedIn;
}

#pragma mark - AwfulTableViewController

- (BOOL)canPullToRefresh
{
    return NO;
}

- (BOOL)refreshOnAppear
{
    return YES;
}

- (void)refresh
{
    [super refresh];
    [self.networkOperation cancel];
    id op = [[AwfulHTTPClient client] learnUserInfoAndThen:^(NSError *error, NSDictionary *userInfo)
    {
        if (error) {
            NSLog(@"failed refreshing user info: %@", error);
        } else {
            NSString *appVersion = [[NSBundle mainBundle]
                                    infoDictionary][@"CFBundleShortVersionString"];
            [AwfulSettings settings].lastForcedUserInfoUpdateVersion = appVersion;
            [AwfulSettings settings].username = userInfo[@"username"];
            [AwfulSettings settings].userID = userInfo[@"userID"];
            [AwfulSettings settings].canSendPrivateMessages = [userInfo[@"canSendPrivateMessages"]
                                                               boolValue];
            [self.tableView reloadData];
            self.refreshing = NO;
        }
    }];
    self.networkOperation = op;
}

#pragma mark - UIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.switches = [NSMutableArray new];
    self.steppers = [NSMutableArray new];
    self.tableView.backgroundView = nil;
    self.tableView.backgroundColor = [UIColor colorWithRed:0.937 green:0.937 blue:0.957 alpha:1];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
}

- (void)reloadSections
{
    NSString *currentDevice = @"iPhone";
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        currentDevice = @"iPad";
    }
    NSMutableArray *sections = [NSMutableArray new];
    for (NSDictionary *section in [AwfulSettings settings].sections) {
        if (section[@"Device"] && ![section[@"Device"] isEqual:currentDevice]) continue;
        if (section[@"VisibleInSettingsTab"] && ![section[@"VisibleInSettingsTab"] boolValue]) {
            continue;
        }
        NSMutableDictionary *filteredSection = [section mutableCopy];
        NSArray *settings = filteredSection[@"Settings"];
        NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(NSDictionary *setting, id _)
        {
            if (!setting[@"PredicateKeyPath"]) return YES;
            return [[self valueForKeyPath:setting[@"PredicateKeyPath"]] boolValue];
        }];
        filteredSection[@"Settings"] = [settings filteredArrayUsingPredicate:predicate];
        [sections addObject:filteredSection];
    }
    self.sections = sections;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self reloadSections];
    [self.tableView reloadData];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                         duration:(NSTimeInterval)duration
{
    // Fix headers and footers on rotate.
    [self.tableView reloadData];
}

#pragma mark - UITableViewDataSource and UITableViewDelegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
    return [self.sections count];
} 

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.sections[section][@"Settings"] count];
}

typedef NS_ENUM(NSUInteger, SettingType)
{
    ImmutableSetting,
    OnOffSetting,
    ChoiceSetting,
    ButtonSetting,
    StepperSetting,
};

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Grab the cell we need.
    
    NSDictionary *setting = [self settingForIndexPath:indexPath];
    SettingType settingType = ImmutableSetting;
    NSString *identifier = @"ImmutableSetting";
    if ([setting[@"Type"] isEqual:@"Switch"]) {
        settingType = OnOffSetting;
        identifier = @"Switch";
    } else if (setting[@"Choices"]) {
        settingType = ChoiceSetting;
        identifier = @"Choices";
    } else if (setting[@"Action"]) {
        settingType = ButtonSetting;
        identifier = @"Action";
    } else if ([setting[@"Type"] isEqual:@"Stepper"]) {
        settingType = StepperSetting;
        identifier = @"Stepper";
    }
    UITableViewCellStyle style = UITableViewCellStyleValue1;
    if (settingType == OnOffSetting || settingType == ButtonSetting) {
        style = UITableViewCellStyleDefault;
    }
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell)
    {
        cell = [[UITableViewCell alloc] initWithStyle:style 
                                      reuseIdentifier:identifier];
        if (settingType == OnOffSetting) {
            UISwitch *switchView = [UISwitch new];
            [switchView addTarget:self
                           action:@selector(hitSwitch:)
                 forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = switchView;
        } else if (settingType == ChoiceSetting) {
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else if (settingType == StepperSetting) {
            UIStepper *stepperView = [UIStepper new];
            [stepperView addTarget:self
                           action:@selector(stepperPressed:)
                 forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = stepperView;
        }
    }
    if (style == UITableViewCellStyleValue1) {
        cell.detailTextLabel.textColor = [UIColor grayColor];
    }
    
    // Set it up as we like it.
    
    if (setting[@"DisplayTransformer"]) {
        NSValueTransformer *transformer = [NSClassFromString(setting[@"DisplayTransformer"]) new];
        if (settingType == ChoiceSetting) {
            cell.textLabel.text = setting[@"Title"];
            cell.detailTextLabel.text = [transformer transformedValue:[AwfulSettings settings]];
        } else {
            cell.textLabel.text = [transformer transformedValue:[AwfulSettings settings]];
        }
    } else {
        cell.textLabel.text = setting[@"Title"];
    }
    cell.textLabel.textColor = [UIColor blackColor];
    
    if (settingType == ImmutableSetting) {
        NSString *valueID = setting[@"ValueIdentifier"];
        if ([valueID isEqualToString:@"Username"]) {
            cell.detailTextLabel.text = [AwfulSettings settings].username;
        } else if ([valueID isEqualToString:@"InstapaperUsername"]) {
            cell.detailTextLabel.text = [AwfulSettings settings].instapaperUsername;
        } else if ([valueID isEqualToString:@"PocketUsername"]) {
            cell.detailTextLabel.text = [AwfulSettings settings].pocketUsername;
        }
    }
    
    NSString *key = setting[@"Key"];
    id valueForSetting = key ? [[NSUserDefaults standardUserDefaults] objectForKey:key] : nil;
    
    if (settingType == OnOffSetting) {
        UISwitch *switchView = (UISwitch *)cell.accessoryView;
        switchView.on = [valueForSetting boolValue];
        NSUInteger tag = [self.switches indexOfObject:indexPath];
        if (tag == NSNotFound) {
            tag = self.switches.count;
            [self.switches addObject:indexPath];
        }
        switchView.tag = tag;
    } else if (settingType == ChoiceSetting) {
        if (setting[@"DisplayTransformer"]) {
            NSValueTransformer *transformer = [NSClassFromString(setting[@"DisplayTransformer"]) new];
            cell.detailTextLabel.text = [transformer transformedValue:[AwfulSettings settings]];
        } else {
            for (NSDictionary *choice in setting[@"Choices"]) {
                if ([choice[@"Value"] isEqual:valueForSetting]) {
                    cell.detailTextLabel.text = choice[@"Title"];
                    break;
                }
            }
        }
    } else if (settingType == StepperSetting) {
        UIStepper *stepperView = (UIStepper *)cell.accessoryView;
        stepperView.minimumValue = [setting[@"Minimum"] integerValue];
        NSNumber *maximum = setting[@"Maximum"];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            maximum = setting[@"Maximum~ipad"] ?: setting[@"Maximum"];
        }
        stepperView.maximumValue = [maximum integerValue];
        stepperView.stepValue = [setting[@"Increment"] integerValue];
        stepperView.value = [valueForSetting integerValue];
        
        NSUInteger tag = [self.steppers indexOfObject:indexPath];
        if (tag == NSNotFound) {
            tag = self.steppers.count;
            [self.steppers addObject:indexPath];
        }
        stepperView.tag = tag;
    }
    
    if (settingType == ChoiceSetting || settingType == ButtonSetting) {
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    } else {
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    
    return cell;
}

- (void)hitSwitch:(UISwitch *)switchView
{
    NSIndexPath *indexPath = self.switches[switchView.tag];
    NSDictionary *setting = [self settingForIndexPath:indexPath];
    NSString *key = setting[@"Key"];
    [AwfulSettings settings][key] = @(switchView.on);
}

- (void)stepperPressed:(UIStepper *)stepperView
{
    NSIndexPath *indexPath = self.steppers[stepperView.tag];
    NSDictionary *setting = [self settingForIndexPath:indexPath];
    NSString *key = setting[@"Key"];
    [AwfulSettings settings][key] = @(stepperView.value);
}

- (NSIndexPath *)tableView:(UITableView *)tableView
  willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *setting = [self settingForIndexPath:indexPath];
    if (setting[@"Action"] || setting[@"Choices"]) {
        return indexPath;
    }
    return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *setting = [self settingForIndexPath:indexPath];
    NSString *action = setting[@"Action"];
    if ([action isEqualToString:@"LogOut"]) {
        AwfulAlertView *alert = [AwfulAlertView new];
        alert.title = @"Log Out";
        alert.message = @"Are you sure you want to log out?";
        [alert addCancelButtonWithTitle:@"Cancel" block:nil];
        [alert addButtonWithTitle:@"Log Out" block:^{ [[AwfulAppDelegate instance] logOut]; }];
        [alert show];
    } else if ([action isEqualToString:@"GoToAwfulThread"]) {
        AwfulPostsViewController *page = [AwfulPostsViewController new];
        page.restorationIdentifier = @"Awful's Thread";
        NSString *threadID = setting[@"ThreadID"];
        page.thread = [AwfulThread firstOrNewThreadWithThreadID:threadID];
        [page loadPage:AwfulThreadPageNextUnread singleUserID:nil];
        if (self.expandingSplitViewController) {
            UINavigationController * nav = [page enclosingNavigationController];
            nav.restorationIdentifier = @"Navigation";
            self.expandingSplitViewController.detailViewController = nav;
        } else {
            [self.navigationController pushViewController:page animated:YES];
        }
    } else if ([action isEqualToString:@"InstapaperLogIn"]) {
        if ([AwfulSettings settings].instapaperUsername) {
            [AwfulSettings settings].instapaperUsername = nil;
            [AwfulSettings settings].instapaperPassword = nil;
            [self reloadSections];
            [tableView reloadSections:[NSIndexSet indexSetWithIndex:indexPath.section]
                     withRowAnimation:UITableViewRowAnimationNone];
        } else {
            AwfulInstapaperLogInController *logIn = [AwfulInstapaperLogInController new];
            logIn.delegate = self;
            [self presentViewController:[logIn enclosingNavigationController]
                               animated:YES completion:nil];
        }
    } else if ([action isEqualToString:@"PocketLogIn"]) {
        if ([[PocketAPI sharedAPI] isLoggedIn]) {
            [[PocketAPI sharedAPI] logout];
            [self reloadSections];
            [tableView reloadSections:[NSIndexSet indexSetWithIndex:indexPath.section]
                     withRowAnimation:UITableViewRowAnimationNone];
            [SVProgressHUD showSuccessWithStatus:@"Logged out"];
        } else {
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
            [[PocketAPI sharedAPI] loginWithHandler: ^(PocketAPI *API, NSError *error){
                [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
                if (error != nil) {
                    [AwfulAlertView showWithTitle:@"Could Not Log in"
                                            error:error
                                      buttonTitle:@"Alright"];
                } else {
                    [self reloadSections];
                    [tableView reloadSections:[NSIndexSet indexSetWithIndex:indexPath.section]
                             withRowAnimation:UITableViewRowAnimationNone];
                    [SVProgressHUD showSuccessWithStatus:@"Logged in to Pocket"];
                }
            }];
        }
    } else {
        UIViewController *viewController;
        if (setting[@"ViewController"]) {
            viewController = [NSClassFromString(setting[@"ViewController"]) new];
        } else {
            viewController = [[AwfulSettingsChoiceViewController alloc] initWithSetting:setting];
        }
        [self.navigationController pushViewController:viewController animated:YES];
    }
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (NSDictionary *)settingForIndexPath:(NSIndexPath *)indexPath
{
    return self.sections[indexPath.section][@"Settings"][indexPath.row];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == 0) {
        NSDictionary *infoPlist = [NSBundle mainBundle].infoDictionary;
        return [NSString stringWithFormat:@"Awful %@", infoPlist[@"CFBundleShortVersionString"]];
    }
    return self.sections[section][@"Title"];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    NSString *title = [tableView.dataSource tableView:tableView titleForHeaderInSection:section];
    return title ? 42 : 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    NSDictionary *sectionInfo = self.sections[section];
    return sectionInfo[@"Explanation"];
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    NSString *text = [tableView.dataSource tableView:tableView titleForFooterInSection:section];
    if (!text) return 0;
    CGSize max = CGSizeMake(tableView.bounds.size.width - 40, CGFLOAT_MAX);
    CGRect expected = [text boundingRectWithSize:max
                                         options:NSStringDrawingUsesLineFragmentOrigin
                                      attributes:@{ NSFontAttributeName: [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1] }
                                         context:nil];
    const CGFloat margin = 14;
    return CGRectGetHeight(expected) + margin;
}

#pragma mark - AwfulInstapaperLogInControllerDelegate

- (void)instapaperLogInControllerDidSucceed:(AwfulInstapaperLogInController *)logIn
{
    [AwfulSettings settings].instapaperUsername = logIn.username;
    [AwfulSettings settings].instapaperPassword = logIn.password;
    [self reloadSections];
    [self.tableView reloadData];
    [logIn dismissViewControllerAnimated:YES completion:nil];
}

- (void)instapaperLogInControllerDidCancel:(AwfulInstapaperLogInController *)logIn
{
    [logIn dismissViewControllerAnimated:YES completion:nil];
}

@end
