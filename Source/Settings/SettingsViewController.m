//  SettingsViewController.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "SettingsViewController.h"
#import "AwfulAppDelegate.h"
#import "AwfulForumsClient.h"
#import "AwfulFrameworkCategories.h"
#import "AwfulInstapaperLogInController.h"
#import "AwfulLoginController.h"
#import "AwfulModels.h"
#import "AwfulProfileViewController.h"
#import "AwfulRefreshMinder.h"
#import "AwfulSettings.h"
#import "InstapaperAPIClient.h"
#import <PocketAPI/PocketAPI.h>
#import "Awful-Swift.h"

@interface SettingsViewController () <AwfulInstapaperLogInControllerDelegate>

@property (strong, nonatomic) NSArray *sections;
@property (strong, nonatomic) NSMutableArray *switches;
@property (strong, nonatomic) NSMutableArray *steppers;

@end


@implementation SettingsViewController

- (id)initWithManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    if (!(self = [super initWithStyle:UITableViewStyleGrouped])) return nil;
    _managedObjectContext = managedObjectContext;
    self.title = @"Settings";
    self.navigationItem.backBarButtonItem = [UIBarButtonItem awful_emptyBackBarButtonItem];
    self.tabBarItem.image = [UIImage imageNamed:@"cog"];
    return self;
}

#pragma mark - Settings predicates

- (BOOL)isLoggedInToInstapaper
{
    return !![AwfulSettings sharedSettings].instapaperUsername;
}

- (BOOL)isLoggedInToPocket
{
    return [PocketAPI sharedAPI].isLoggedIn;
}

#pragma mark - UIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.switches = [NSMutableArray new];
    self.steppers = [NSMutableArray new];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
}

- (void)reloadSections
{
    NSString *currentDevice = @"iPhone";
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        currentDevice = @"iPad";
    }
    NSMutableArray *sections = [NSMutableArray new];
    for (NSDictionary *section in [AwfulSettings sharedSettings].sections) {
        if (section[@"Device"] && ![section[@"Device"] isEqual:currentDevice]) continue;
        if (section[@"VisibleInSettingsTab"] && ![section[@"VisibleInSettingsTab"] boolValue]) {
            continue;
        }
        NSMutableDictionary *filteredSection = [section mutableCopy];
        NSArray *settings = filteredSection[@"Settings"];
        NSPredicate *predicate = [NSPredicate predicateWithBlock:^(NSDictionary *setting, id _)
        {
            NSString *device = setting[@"Device"];
            if (device && ![device isEqual:currentDevice]) return NO;
            
            NSString *keyPath = setting[@"PredicateKeyPath"];
            if (keyPath) return [[self valueForKeyPath:setting[@"PredicateKeyPath"]] boolValue];
            return YES;
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

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self refreshIfNecessary];
}

- (void)refreshIfNecessary
{
    if ([[AwfulRefreshMinder minder] shouldRefreshLoggedInUser]) {
        __weak UITableView *tableView = self.tableView;
        [[AwfulForumsClient client] learnLoggedInUserInfoAndThen:^(NSError *error, AwfulUser *user) {
            if (error) {
                NSLog(@"failed refreshing user info: %@", error);
            } else {
                [tableView reloadData];
                [[AwfulRefreshMinder minder] didFinishRefreshingLoggedInUser];
            }
        }];
    }
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
    ButtonSetting,
    StepperSetting,
    DisclosureSetting,
    DisclosureDetailSetting,
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
    } else if (setting[@"Action"] && ![setting[@"Action"] isEqual:@"ShowProfile"]) {
        settingType = ButtonSetting;
        identifier = @"Action";
    } else if ([setting[@"Type"] isEqual:@"Stepper"]) {
        settingType = StepperSetting;
        identifier = @"Stepper";
    } else if (setting[@"ViewController"]) {
        if (setting[@"DisplayTransformer"]) {
            settingType = DisclosureDetailSetting;
            identifier = @"DisclosureDetail";
        } else {
            settingType = DisclosureSetting;
            identifier = @"Disclosure";
        }
    }
    UITableViewCellStyle style = UITableViewCellStyleValue1;
    if (settingType == OnOffSetting || settingType == ButtonSetting || settingType == DisclosureSetting) {
        style = UITableViewCellStyleDefault;
    }
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:style  reuseIdentifier:identifier];
        if (settingType == OnOffSetting) {
            UISwitch *switchView = [UISwitch new];
            [switchView addTarget:self
                           action:@selector(hitSwitch:)
                 forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = switchView;
        } else if (settingType == DisclosureSetting || settingType == DisclosureDetailSetting) {
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.accessibilityTraits |= UIAccessibilityTraitButton;
        } else if (settingType == StepperSetting) {
            UIStepper *stepperView = [UIStepper new];
            [stepperView addTarget:self
                           action:@selector(stepperPressed:)
                 forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = stepperView;
        } else if (settingType == ButtonSetting) {
            cell.accessibilityTraits |= UIAccessibilityTraitButton;
        }
    }
    if (style == UITableViewCellStyleValue1) {
        cell.detailTextLabel.textColor = [UIColor grayColor];
    }
    
    // Set it up as we like it.
    
    if (setting[@"DisplayTransformer"]) {
        NSValueTransformer *transformer = [NSClassFromString(setting[@"DisplayTransformer"]) new];
        if (settingType == DisclosureDetailSetting) {
            cell.textLabel.text = setting[@"Title"];
            cell.detailTextLabel.text = [transformer transformedValue:[AwfulSettings sharedSettings]];
        } else {
            cell.textLabel.text = [transformer transformedValue:[AwfulSettings sharedSettings]];
        }
    } else {
        cell.textLabel.text = setting[@"Title"];
    }
    cell.textLabel.textColor = [UIColor blackColor];
    
    if (settingType == ImmutableSetting) {
        NSString *valueID = setting[@"ValueIdentifier"];
        if ([valueID isEqualToString:@"Username"]) {
            cell.detailTextLabel.text = [AwfulSettings sharedSettings].username;
        } else if ([valueID isEqualToString:@"InstapaperUsername"]) {
            cell.detailTextLabel.text = [AwfulSettings sharedSettings].instapaperUsername;
        } else if ([valueID isEqualToString:@"PocketUsername"]) {
            cell.detailTextLabel.text = [AwfulSettings sharedSettings].pocketUsername;
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
        cell.textLabel.text = [NSString stringWithFormat:setting[@"Title"], (int)stepperView.value];
        
        NSUInteger tag = [self.steppers indexOfObject:indexPath];
        if (tag == NSNotFound) {
            tag = self.steppers.count;
            [self.steppers addObject:indexPath];
        }
        stepperView.tag = tag;
    }
    
    if (settingType == ButtonSetting || settingType == DisclosureSetting || settingType == DisclosureDetailSetting) {
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    } else {
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    
    AwfulTheme *theme = self.theme;
    cell.backgroundColor = theme[@"listBackgroundColor"];
    cell.textLabel.textColor = theme[@"listTextColor"];
    UIView *selectedBackgroundView = [UIView new];
    selectedBackgroundView.backgroundColor = theme[@"listSelectedBackgroundColor"];
    cell.selectedBackgroundView = selectedBackgroundView;
    if ([cell.accessoryView isKindOfClass:[UISwitch class]]) {
        UIColor *color = theme[@"settingsSwitchColor"];
        [(UISwitch*)cell.accessoryView setOnTintColor:color];
    }
	
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UITableViewHeaderFooterView *)view forSection:(NSInteger)section
{
    view.contentView.backgroundColor = self.theme[@"listHeaderBackgroundColor"];
}

- (void)tableView:(UITableView *)tableView willDisplayFooterView:(UITableViewHeaderFooterView *)view forSection:(NSInteger)section
{
    view.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    view.contentView.backgroundColor = self.theme[@"listHeaderBackgroundColor"];
}

- (void)hitSwitch:(UISwitch *)switchView
{
    NSIndexPath *indexPath = self.switches[switchView.tag];
    NSDictionary *setting = [self settingForIndexPath:indexPath];
    NSString *key = setting[@"Key"];
    [AwfulSettings sharedSettings][key] = @(switchView.on);
}

- (void)stepperPressed:(UIStepper *)stepperView
{
    NSIndexPath *indexPath = self.steppers[stepperView.tag];
    NSDictionary *setting = [self settingForIndexPath:indexPath];
    NSString *key = setting[@"Key"];
    [AwfulSettings sharedSettings][key] = @(stepperView.value);

    // Redisplay to update title
    [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationNone];
}

- (NSIndexPath *)tableView:(UITableView *)tableView
  willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *setting = [self settingForIndexPath:indexPath];
    if (setting[@"Action"] || setting[@"Choices"] || setting[@"ViewController"]) {
        return indexPath;
    }
    return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *setting = [self settingForIndexPath:indexPath];
    NSString *action = setting[@"Action"];
    if ([action isEqualToString:@"ShowProfile"]) {
        AwfulUser *loggedInUser = [AwfulUser firstOrNewUserWithUserID:[AwfulSettings sharedSettings].userID
                                                             username:[AwfulSettings sharedSettings].username
                                               inManagedObjectContext:self.managedObjectContext];
        AwfulProfileViewController *profile = [[AwfulProfileViewController alloc] initWithUser:loggedInUser];
        [self presentViewController:[profile enclosingNavigationController] animated:YES completion:nil];
    } else if ([action isEqualToString:@"LogOut"]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Log Out"
                                                                       message:@"Are you sure you want to log out?"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Log Out" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [[AwfulAppDelegate instance] logOut];
        }]];
        [self presentViewController:alert animated:YES completion:nil];
    } else if ([action isEqualToString:@"GoToAwfulThread"]) {
        NSURL *URL = [NSURL URLWithString:[NSString stringWithFormat:@"awful://threads/%@", setting[@"ThreadID"]]];
        [[AwfulAppDelegate instance] openAwfulURL:URL];
    } else if ([action isEqualToString:@"InstapaperLogIn"]) {
        if ([AwfulSettings sharedSettings].instapaperUsername) {
            [AwfulSettings sharedSettings].instapaperUsername = nil;
            [AwfulSettings sharedSettings].instapaperPassword = nil;
            [self reloadSections];
            [tableView reloadData];
        } else {
            AwfulInstapaperLogInController *logIn = [AwfulInstapaperLogInController new];
            logIn.delegate = self;
            [self presentViewController:[logIn enclosingNavigationController] animated:YES completion:nil];
        }
    } else if ([action isEqualToString:@"PocketLogIn"]) {
        if ([[PocketAPI sharedAPI] isLoggedIn]) {
            [[PocketAPI sharedAPI] logout];
            [self reloadSections];
            [tableView reloadData];
        } else {
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
            [[PocketAPI sharedAPI] loginWithHandler: ^(PocketAPI *API, NSError *error){
                [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
                if (error) {
                    [self presentViewController:[UIAlertController alertWithTitle:@"Could Not Log in" error:error] animated:YES completion:nil];
                } else {
                    [self reloadSections];
                    [tableView reloadData];
                }
            }];
        }
    } else if (setting[@"ViewController"]) {
        UIViewController *viewController = [NSClassFromString(setting[@"ViewController"]) new];
        [self.navigationController pushViewController:viewController animated:YES];
    } else {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"don't know how to handle selection of setting" userInfo:nil];
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
    return sectionInfo[@"Explanation"] ?: @" ";
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    NSString *text = [tableView.dataSource tableView:tableView titleForFooterInSection:section];
    if (!text) return 0;
    CGSize max = CGSizeMake(tableView.bounds.size.width - 40, CGFLOAT_MAX);
    CGRect expected = [text boundingRectWithSize:max
                                         options:NSStringDrawingUsesLineFragmentOrigin
                                      attributes:@{ NSFontAttributeName: [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote] }
                                         context:nil];
    const CGFloat margin = 14;
    return ceil(CGRectGetHeight(expected)) + margin;
}

#pragma mark - AwfulInstapaperLogInControllerDelegate

- (void)instapaperLogInControllerDidSucceed:(AwfulInstapaperLogInController *)logIn
{
    [AwfulSettings sharedSettings].instapaperUsername = logIn.username;
    [AwfulSettings sharedSettings].instapaperPassword = logIn.password;
    [self reloadSections];
    [self.tableView reloadData];
    [logIn dismissViewControllerAnimated:YES completion:nil];
}

- (void)instapaperLogInControllerDidCancel:(AwfulInstapaperLogInController *)logIn
{
    [logIn dismissViewControllerAnimated:YES completion:nil];
}

@end
