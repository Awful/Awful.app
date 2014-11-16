//  SettingsViewController.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "SettingsViewController.h"
#import "AwfulAppDelegate.h"
#import "AwfulAvatarLoader.h"
#import "AwfulForumsClient.h"
#import "AwfulFrameworkCategories.h"
#import "AwfulRefreshMinder.h"
#import "AwfulSettings.h"
#import "SettingsBinding.h"
#import "Awful-Swift.h"

@interface SettingsViewController ()

@property (strong, nonatomic) NSArray *sections;
@property (readonly, strong, nonatomic) User *loggedInUser;

@end

@implementation SettingsViewController

- (instancetype)initWithManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
        _managedObjectContext = managedObjectContext;
        self.title = @"Settings";
        self.navigationItem.backBarButtonItem = [UIBarButtonItem awful_emptyBackBarButtonItem];
        self.tabBarItem.image = [UIImage imageNamed:@"cog"];
    }
    return self;
}

- (NSArray *)sections
{
    if (!_sections) {
        NSString *currentDevice = @"iPhone";
        
        // For settings purposes, we consider devices with a regular horizontal size class in landscape to be iPads. This includes iPads and also the iPhone 6 Plus.
        // TODO Find a better way of doing this than checking the displayScale.
        if (self.traitCollection.userInterfaceIdiom == UIUserInterfaceIdiomPad || self.traitCollection.displayScale == 3.0) {
            currentDevice = @"iPad";
        }
        
        NSMutableArray *sections = [NSMutableArray new];
        for (NSDictionary *section in [AwfulSettings sharedSettings].sections) {
            
            // Check for prefix so that "iPad-like" also matches.
            if (section[@"Device"] && ![section[@"Device"] hasPrefix:currentDevice]) continue;
            if (section[@"VisibleInSettingsTab"] && ![section[@"VisibleInSettingsTab"] boolValue]) continue;
            NSMutableDictionary *filteredSection = [section mutableCopy];
            NSArray *settings = filteredSection[@"Settings"];
            NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(NSDictionary *setting, id _) {
                NSString *device = setting[@"Device"];
                
                // Again, check for prefix so that "iPad-like" also matches.
                return !device || [device hasPrefix:currentDevice];
            }];
            filteredSection[@"Settings"] = [settings filteredArrayUsingPredicate:predicate];
            [sections addObject:filteredSection];
        }
        _sections = sections;
    }
    return _sections;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
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
        [[AwfulForumsClient client] learnLoggedInUserInfoAndThen:^(NSError *error, User *user) {
            if (error) {
                NSLog(@"failed refreshing user info: %@", error);
            } else {
                [tableView reloadData];
                [[AwfulRefreshMinder minder] didFinishRefreshingLoggedInUser];
            }
        }];
    }
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [coordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [self.tableView reloadData];
    }];
}

- (void)showProfile
{
    ProfileViewController *profile = [[ProfileViewController alloc] initWithUser:self.loggedInUser];
    [self presentViewController:[profile enclosingNavigationController] animated:YES completion:nil];
}

- (User *)loggedInUser
{
    AwfulSettings *settings = [AwfulSettings sharedSettings];
    UserKey *userKey = [[UserKey alloc] initWithUserID:settings.userID username:settings.username];
    return [User objectForKey:userKey inManagedObjectContext:self.managedObjectContext];
}

#pragma mark - UITableViewDataSource and UITableViewDelegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
    return self.sections.count;
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
    if ([action isEqualToString:@"LogOut"]) {
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
    NSDictionary *settingSection = self.sections[section];
    if (settingSection[@"TitleKey"]) {
        return [AwfulSettings sharedSettings][settingSection[@"TitleKey"]];
    } else {
        NSString *title = settingSection[@"Title"];
        if ([title isEqualToString:@"Awful x.y.z"]) {
            NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
            title = [NSString stringWithFormat:@"Awful %@", version];
        }
        return title;
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    NSDictionary *settingSection = self.sections[section];
    if (settingSection[@"Action"]) {
        SettingsAvatarHeader *header = [SettingsAvatarHeader newFromNib];
        if (settingSection[@"TitleKey"]) {
            header.usernameLabel.awful_setting = settingSection[@"TitleKey"];
        }
        header.usernameLabel.textColor = self.theme[@"listTextColor"];
        header.contentEdgeInsets = self.tableView.separatorInset;
        if ([settingSection[@"Action"] isEqualToString:@"ShowProfile"]) {
            [header setTarget:self action:NSStringFromSelector(@selector(showProfile))];
        }
        [[AwfulAvatarLoader loader] applyCachedAvatarImageForUser:self.loggedInUser toImageView:header.avatarImageView];
        [header.avatarImageView startAnimating];
        [[AwfulAvatarLoader loader] applyAvatarImageForUser:self.loggedInUser completionBlock:^(BOOL modified, void (^applyBlock)(UIImageView *), NSError *error) {
            if (modified) {
                applyBlock(header.avatarImageView);
                [header.avatarImageView startAnimating];
            }
        }];
        return header;
    } else {
        return nil;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return UITableViewAutomaticDimension;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    NSDictionary *sectionInfo = self.sections[section];
    return sectionInfo[@"Explanation"];
}

@end
