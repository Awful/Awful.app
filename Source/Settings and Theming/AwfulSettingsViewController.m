//
//  AwfulSettingsViewController.m
//  Awful
//
//  Created by Sean Berry on 3/1/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulSettingsViewController.h"
#import "AwfulAlertView.h"
#import "AwfulAppDelegate.h"
#import "AwfulDisclosureIndicatorView.h"
#import "AwfulHTTPClient.h"
#import "AwfulLicensesViewController.h"
#import "AwfulLoginController.h"
#import "AwfulModels.h"
#import "AwfulPostsViewController.h"
#import "AwfulSettings.h"
#import "AwfulSettingsChoiceViewController.h"
#import "AwfulSplitViewController.h"
#import "AwfulTheme.h"
#import "NSManagedObject+Awful.h"
#import "UIViewController+NavigationEnclosure.h"

@interface AwfulSettingsViewController ()

@property (strong, nonatomic) NSArray *sections;

@property (strong, nonatomic) NSMutableArray *switches;

@property (strong, nonatomic) NSMutableArray *sliders;

@property (nonatomic) BOOL canReachDevDotForums;

@end


@implementation AwfulSettingsViewController

- (id)init
{
    if (!(self = [super initWithStyle:UITableViewStyleGrouped])) return nil;
    self.title = @"Settings";
    self.tabBarItem.image = [UIImage imageNamed:@"cog.png"];
    return self;
}

- (void)dismissLicenses
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)canReachDevDotForums
{
    if (_canReachDevDotForums) return _canReachDevDotForums;
    if ([AwfulSettings settings].useDevDotForums) {
        _canReachDevDotForums = YES;
        return _canReachDevDotForums;
    }
    __weak AwfulSettingsViewController *weakSelf = self;
    [[AwfulHTTPClient client] tryAccessingDevDotForumsAndThen:^(NSError *error, BOOL success) {
        AwfulSettingsViewController *strongSelf = weakSelf;
        strongSelf.canReachDevDotForums = success;
        if (success) {
            [strongSelf reloadSections];
            [strongSelf.tableView reloadData];
        }
    }];
    return _canReachDevDotForums;
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
            [AwfulSettings settings].username = userInfo[@"username"];
            [AwfulSettings settings].userID = userInfo[@"userID"];
            [self.tableView reloadData];
            self.refreshing = NO;
        }
    }];
    self.networkOperation = op;
}

- (void)retheme
{
    [super retheme];
    self.tableView.backgroundColor = [AwfulTheme currentTheme].settingsViewBackgroundColor;
    self.tableView.separatorColor = [AwfulTheme currentTheme].settingsCellSeparatorColor;
}

#pragma mark - UIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.switches = [NSMutableArray new];
    self.sliders = [NSMutableArray new];
    self.tableView.backgroundView = nil;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    
    // Make sure the bottom section's footer is visible.
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, 18, 0);
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
        if (section[@"Predicate"]) {
            NSPredicate *predicate = [NSPredicate predicateWithFormat:section[@"Predicate"]];
            if (![predicate evaluateWithObject:self]) continue;
        }
        [sections addObject:section];
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

typedef enum SettingType
{
    ImmutableSetting,
    OnOffSetting,
    ChoiceSetting,
    ButtonSetting,
    SliderSetting,
} SettingType;

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
    } else if ([setting[@"Type"] isEqual:@"Slider"]) {
        settingType = SliderSetting;
        identifier = @"Slider";
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
            cell.accessoryView = [AwfulDisclosureIndicatorView new];
        } else if (settingType == SliderSetting) {
            UISlider *sliderView = [UISlider new];
            [sliderView addTarget:self
                           action:@selector(moveSlider:)
                 forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = sliderView;
        }
    }
    if (style == UITableViewCellStyleValue1) {
        UIColor *color = [AwfulTheme currentTheme].settingsCellCurrentValueTextColor;
        cell.detailTextLabel.textColor = color;
    }
    
    // Set it up as we like it.
    
    cell.textLabel.text = setting[@"Title"];
    cell.textLabel.textColor = [AwfulTheme currentTheme].settingsCellTextColor;
    
    if (settingType == ImmutableSetting) {
        // This only works because there's one immutable setting here.
        cell.detailTextLabel.text = [AwfulSettings settings].username;
    }
    
    NSString *key = setting[@"Key"];
    id valueForSetting = key ? [[NSUserDefaults standardUserDefaults] objectForKey:key] : nil;
    
    if (settingType == OnOffSetting) {
        UISwitch *switchView = (UISwitch *)cell.accessoryView;
        switchView.on = [valueForSetting boolValue];
        switchView.onTintColor = [AwfulTheme currentTheme].settingsCellSwitchOnTintColor;
        NSUInteger tag = [self.switches indexOfObject:indexPath];
        if (tag == NSNotFound) {
            tag = self.switches.count;
            [self.switches addObject:indexPath];
        }
        switchView.tag = tag;
    } else if (settingType == ChoiceSetting) {
        AwfulDisclosureIndicatorView *disclosure = (AwfulDisclosureIndicatorView *)cell.accessoryView;
        disclosure.color = [AwfulTheme currentTheme].disclosureIndicatorColor;
        disclosure.highlightedColor = [AwfulTheme currentTheme].disclosureIndicatorHighlightedColor;
        for (NSDictionary *choice in setting[@"Choices"]) {
            if ([choice[@"Value"] isEqual:valueForSetting]) {
                cell.detailTextLabel.text = choice[@"Title"];
                break;
            }
        }
    } else if (settingType == SliderSetting) {
        UISlider *sliderView = (UISlider *)cell.accessoryView;
        sliderView.minimumValue = [setting[@"Minimum"] floatValue];
        sliderView.maximumValue = [setting[@"Maximum"] floatValue];
        sliderView.value = [setting[@"Default"] floatValue];
        sliderView.continuous = NO;
        sliderView.value = [valueForSetting floatValue];
        NSUInteger tag = [self.sliders indexOfObject:indexPath];
        if (tag == NSNotFound) {
            tag = self.sliders.count;
            [self.sliders addObject:indexPath];
        }
        sliderView.tag = tag;
    }
    
    if (settingType == ChoiceSetting || settingType == ButtonSetting) {
        cell.selectionStyle = [AwfulTheme currentTheme].cellSelectionStyle;
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
    NSIndexPath *indexPath = self.switches[switchView.tag];
    NSDictionary *setting = [self settingForIndexPath:indexPath];
    NSString *key = setting[@"Key"];
    [AwfulSettings settings][key] = @(switchView.on);
    
}

- (void)moveSlider:(UISlider *)sliderView
{
    NSIndexPath *indexPath = self.sliders[sliderView.tag];
    NSDictionary *setting = [self settingForIndexPath:indexPath];
    NSString *key = setting[@"Key"];
    //NSLog(@"setting slider '%@' to value: %f", key, sliderView.value);
    [AwfulSettings settings][key] = @(sliderView.value);
}

- (void)tableView:(UITableView *)tableView
  willDisplayCell:(UITableViewCell *)cell
forRowAtIndexPath:(NSIndexPath *)indexPath
{
    cell.backgroundColor = [AwfulTheme currentTheme].settingsCellBackgroundColor;
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
        NSString *threadID = setting[@"ThreadID"];
        page.thread = [AwfulThread firstOrNewThreadWithThreadID:threadID];
        [page loadPage:AwfulThreadPageNextUnread];
        if (self.splitViewController) {
            AwfulSplitViewController *split = (AwfulSplitViewController *)self.splitViewController;
            UINavigationController *nav = split.viewControllers[1];
            [nav setViewControllers:@[ page ] animated:NO];
            [split.masterPopoverController dismissPopoverAnimated:YES];
        } else {
            [self.navigationController pushViewController:page animated:YES];
        }
    } else if ([action isEqualToString:@"ShowLicenses"]) {
        AwfulLicensesViewController *licenses = [AwfulLicensesViewController new];
        UIBarButtonItem *doneItem = [[UIBarButtonItem alloc]
                                     initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                     target:self action:@selector(dismissLicenses)];
        licenses.navigationItem.rightBarButtonItem = doneItem;
        UINavigationController *nav = [licenses enclosingNavigationController];
        nav.modalPresentationStyle = UIModalPresentationFormSheet;
        [self presentViewController:nav animated:YES completion:nil];
    } else {
        AwfulSettingsChoiceViewController *choiceViewController;
        choiceViewController = [[AwfulSettingsChoiceViewController alloc] initWithSetting:setting];
        [self.navigationController pushViewController:choiceViewController animated:YES];
    }
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (NSDictionary *)settingForIndexPath:(NSIndexPath *)indexPath
{
    return self.sections[indexPath.section][@"Settings"][indexPath.row];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return self.sections[section][@"Title"];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    NSString *title = [tableView.dataSource tableView:tableView titleForHeaderInSection:section];
    if (!title && section == 0) {
        NSDictionary *infoPlist = [[NSBundle mainBundle] infoDictionary];
        title = [NSString stringWithFormat:@"Awful %@", infoPlist[@"CFBundleShortVersionString"]];
    }
    if (!title) return nil;
    
    UILabel *label = [UILabel new];
    label.frame = CGRectMake(20, 13, tableView.bounds.size.width - 40, 30);
    label.font = [UIFont boldSystemFontOfSize:17];
    label.text = title;
    label.backgroundColor = [UIColor clearColor];
    label.textColor = [AwfulTheme currentTheme].settingsViewHeaderTextColor;
    label.shadowColor = [AwfulTheme currentTheme].settingsViewHeaderShadowColor;
    label.shadowOffset = CGSizeMake(-1, 1);

    UIView *wrapper = [UIView new];
    wrapper.frame = (CGRect){ .size = { 320, 40 } };
    wrapper.backgroundColor = [UIColor clearColor];
    [wrapper addSubview:label];
    return wrapper;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    NSString *title = [tableView.dataSource tableView:tableView titleForHeaderInSection:section];
    return title || section == 0 ? 47 : 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    NSDictionary *sectionInfo = self.sections[section];
    NSString *iOSVersion = [UIDevice currentDevice].systemVersion;
    if ([iOSVersion compare:@"6.0" options:NSNumericSearch] == NSOrderedAscending) {
        return sectionInfo[@"Explanation~ios5"] ?: sectionInfo[@"Explanation"];
    }
    return sectionInfo[@"Explanation"];
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    NSString *text = [tableView.dataSource tableView:tableView titleForFooterInSection:section];
    if (!text) return nil;
    
    UILabel *label = [UILabel new];
    label.numberOfLines = 0;
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [UIFont systemFontOfSize:15];
    CGFloat width = self.tableView.bounds.size.width - 40;
    label.frame = CGRectMake(20, 5, width, 0);
    label.text = text;
    label.backgroundColor = [UIColor clearColor];
    label.textColor = [AwfulTheme currentTheme].settingsViewFooterTextColor;
    label.shadowColor = [AwfulTheme currentTheme].settingsViewFooterShadowColor;
    label.shadowOffset = CGSizeMake(0, 1);
    [label sizeToFit];
    CGRect frame = label.frame;
    frame.size.width = width;
    label.frame = frame;
    
    UIView *wrapper = [UIView new];
    wrapper.frame = (CGRect){ .size = { 320, label.bounds.size.height + 5 } };
    wrapper.backgroundColor = [UIColor clearColor];
    [wrapper addSubview:label];
    return wrapper;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    CGFloat margin = 22;
    if (section + 1 == tableView.numberOfSections) margin = 0;
    NSString *text = [tableView.dataSource tableView:tableView titleForFooterInSection:section];
    if (!text) return margin;
    CGSize max = CGSizeMake(tableView.bounds.size.width - 40, CGFLOAT_MAX);
    CGSize expected = [text sizeWithFont:[UIFont systemFontOfSize:15]
                                constrainedToSize:max];
    return expected.height + margin;
}

@end
