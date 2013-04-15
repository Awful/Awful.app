//
//  AwfulSettingsChoiceViewController.m
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import "AwfulSettingsChoiceViewController.h"
#import "AwfulSettings.h"
#import "AwfulTheme.h"
#import "AwfulThemingViewController.h"

@interface AwfulSettingsChoiceViewController () <AwfulThemingViewController>

@property (strong) NSDictionary *setting;
@property (weak) id selectedValue;
@property (strong) NSIndexPath *currentIndexPath;

@end


@implementation AwfulSettingsChoiceViewController

- (id)initWithSetting:(NSDictionary *)setting
{
    if (!(self = [super initWithStyle:UITableViewStyleGrouped])) return nil;
    self.setting = setting;
    self.selectedValue = [[NSUserDefaults standardUserDefaults] valueForKey:self.setting[@"Key"]];
    self.title = setting[@"Title"];
    return self;
}

#pragma mark - AwfulThemingViewController

- (void)retheme
{
    self.tableView.backgroundColor = [AwfulTheme currentTheme].settingsViewBackgroundColor;
    self.tableView.separatorColor = [AwfulTheme currentTheme].settingsCellSeparatorColor;
    [self.tableView reloadData];
}

#pragma mark - UITableViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    return [self initWithSetting:nil];
}

#pragma mark - UIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self retheme];
    self.tableView.backgroundView = nil;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return YES;
    }
    return interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

#pragma mark - UITableView data source and delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[self.setting objectForKey:@"Choices"] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:CellIdentifier];
    }
    NSDictionary *choice = self.setting[@"Choices"][indexPath.row];
    cell.textLabel.text = choice[@"Title"];
    cell.textLabel.textColor = [AwfulTheme currentTheme].settingsCellTextColor;
    if ([choice[@"Value"] isEqual:self.selectedValue]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
        self.currentIndexPath = indexPath;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    cell.selectionStyle = [AwfulTheme currentTheme].cellSelectionStyle;
    return cell;
}

- (void)tableView:(UITableView *)tableView
  willDisplayCell:(UITableViewCell *)cell
forRowAtIndexPath:(NSIndexPath *)indexPath
{
    cell.backgroundColor = [AwfulTheme currentTheme].settingsCellBackgroundColor;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if ([indexPath isEqual:self.currentIndexPath]) return;
    NSDictionary *choice = self.setting[@"Choices"][indexPath.row];
    self.selectedValue = choice[@"Value"];
    [AwfulSettings settings][self.setting[@"Key"]] = self.selectedValue;
    UITableViewCell *oldCell = [tableView cellForRowAtIndexPath:self.currentIndexPath];
    oldCell.accessoryType = UITableViewCellAccessoryNone;
    UITableViewCell *newCell = [tableView cellForRowAtIndexPath:indexPath];
    newCell.accessoryType = UITableViewCellAccessoryCheckmark;
    self.currentIndexPath = indexPath;
}

@end
