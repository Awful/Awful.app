//  AwfulSettingsChoiceViewController.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulSettingsChoiceViewController.h"
#import "AwfulSettings.h"

@interface AwfulSettingsChoiceViewController ()

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

#pragma mark - UITableViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    return [self initWithSetting:nil];
}

#pragma mark - UIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.tableView.backgroundView = nil;
    self.tableView.backgroundColor = [UIColor colorWithHue:0.604 saturation:0.035 brightness:0.898 alpha:1];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
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
    if ([choice[@"Value"] isEqual:self.selectedValue]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
        self.currentIndexPath = indexPath;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    return cell;
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
