//  SettingsViewController.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "SettingsViewController.h"
#import "AwfulAppDelegate.h"
#import "AwfulForumsClient.h"
#import "AwfulFrameworkCategories.h"
#import "AwfulLoginController.h"
#import "AwfulModels.h"
#import "AwfulRefreshMinder.h"
#import "AwfulSettings.h"
#import "SettingsBinding.h"
#import "Awful-Swift.h"

@interface SettingsViewController ()

@property (strong, nonatomic) NSArray *sections;

@end

@implementation SettingsViewController

- (id)initWithManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
        _managedObjectContext = managedObjectContext;
        self.title = @"Settings";
        self.navigationItem.backBarButtonItem = [UIBarButtonItem awful_emptyBackBarButtonItem];
        self.tabBarItem.image = [UIImage imageNamed:@"cog"];
    }
    return self;
}

#pragma mark - UIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
}

- (void)reloadSections
{
    NSString *currentDevice = self.traitCollection.userInterfaceIdiom == UIUserInterfaceIdiomPad ? @"iPad" : @"iPhone";
    self.sections = [[AwfulSettings sharedSettings].sections filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^(NSDictionary *section, NSDictionary *bindings) {
        if (section[@"Device"] && ![section[@"Device"] isEqual:currentDevice]) return NO;
        if (section[@"VisibleInSettingsTab"] && ![section[@"VisibleInSettingsTab"] boolValue]) return NO;
        return YES;
    }]];
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

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
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
            cell.accessoryView = [UISwitch new];
        } else if (settingType == DisclosureSetting || settingType == DisclosureDetailSetting) {
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.accessibilityTraits |= UIAccessibilityTraitButton;
        } else if (settingType == StepperSetting) {
            cell.accessoryView = [UIStepper new];
        } else if (settingType == ButtonSetting) {
            cell.accessibilityTraits |= UIAccessibilityTraitButton;
            if (setting[@"ThreadID"]) {
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            } else {
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
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
        }
    }
    
    if (settingType == OnOffSetting) {
        UISwitch *switchView = (UISwitch *)cell.accessoryView;
        switchView.awful_setting = setting[@"Key"];
    } else if (settingType == StepperSetting) {
        UIStepper *stepper = (UIStepper *)cell.accessoryView;
        stepper.awful_setting = setting[@"Key"];
        cell.textLabel.awful_setting = setting[@"Key"];
        cell.textLabel.awful_settingFormatString = setting[@"Title"];
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

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
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
        ProfileViewController *profile = [[ProfileViewController alloc] initWithUser:loggedInUser];
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

@end
