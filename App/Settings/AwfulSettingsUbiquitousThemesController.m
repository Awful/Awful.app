//  AwfulSettingsUbiquitousThemesController.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulSettingsUbiquitousThemesController.h"
#import "Awful-Swift.h"

@interface AwfulSettingsUbiquitousThemesController ()

@property (copy, nonatomic) NSArray *themes;
@property (copy, nonatomic) NSArray *selectedThemeNames;

@property (assign, nonatomic) BOOL ignoreSettingsChanges;

@end

@implementation AwfulSettingsUbiquitousThemesController

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)init
{
    return [self initWithStyle:UITableViewStyleGrouped];
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        self.title = @"Forum-Specific Themes";
        [self loadData];
    }
    return self;
}

- (void)loadData
{
    self.themes = [[Theme allThemes] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(Theme *theme, NSDictionary *_) {
        return theme.forumID != nil;
    }]];
    self.selectedThemeNames = [AwfulSettings sharedSettings].ubiquitousThemeNames;
}

- (void)settingsDidChange:(NSNotification *)notification
{
    if (self.ignoreSettingsChanges) return;
    if ([notification.userInfo[AwfulSettingsDidChangeSettingKey] isEqualToString:AwfulSettingsKeys.ubiquitousThemeNames]) {
        [self loadData];
        if ([self isViewLoaded]) [self.tableView reloadData];
    }
}

- (void)loadView
{
    [super loadView];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:CellIdentifier];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsDidChange:) name:AwfulSettingsDidChangeNotification object:nil];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.themes.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    Theme *theme = self.themes[indexPath.row];
    
    {{
        cell.textLabel.text = theme.descriptiveName;
        if ([self.selectedThemeNames containsObject:theme.name]) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    }}
    
    {{
        cell.textLabel.textColor = theme[@"listTextColor"];
        UIFontDescriptor *textLabelDescriptor = [UIFontDescriptor preferredFontDescriptorWithTextStyle:UIFontTextStyleSubheadline];
        cell.textLabel.font = [UIFont fontWithName:(theme[@"listFontName"] ?: [textLabelDescriptor objectForKey:UIFontDescriptorNameAttribute])
                                              size:textLabelDescriptor.pointSize];
        cell.tintColor = theme[@"listSecondaryTextColor"];
        cell.backgroundColor = theme[@"listBackgroundColor"];
        if (!cell.selectedBackgroundView) {
            cell.selectedBackgroundView = [UIView new];
        }
        cell.selectedBackgroundView.backgroundColor = theme[@"listSelectedBackgroundColor"];
    }}
    return cell;
}

static NSString * const CellIdentifier = @"Cell";

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    return @"Selected themes become available in every forum.";
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    NSString *text = [tableView.dataSource tableView:tableView titleForFooterInSection:section];
    CGSize max = CGSizeMake(CGRectGetWidth(tableView.bounds) - 40, CGFLOAT_MAX);
    CGRect expected = [text boundingRectWithSize:max
                                         options:NSStringDrawingUsesLineFragmentOrigin
                                      attributes:@{ NSFontAttributeName: [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote] }
                                         context:nil];
    const CGFloat margin = 14;
    return ceil(CGRectGetHeight(expected)) + margin;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    Theme *theme = self.themes[indexPath.row];
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    NSMutableArray *updatedSelection = [self.selectedThemeNames mutableCopy] ?: [NSMutableArray new];
    if ([self.selectedThemeNames containsObject:theme.name]) {
        [updatedSelection removeObject:theme.name];
        cell.accessoryType = UITableViewCellAccessoryNone;
    } else {
        [updatedSelection addObject:theme.name];
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    }
    self.ignoreSettingsChanges = YES;
    [AwfulSettings sharedSettings].ubiquitousThemeNames = updatedSelection;
    self.selectedThemeNames = updatedSelection;
    self.ignoreSettingsChanges = NO;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    // BUG: On iOS 7 by default there's a stubborn 35pt top margin. This removes that margin.
    return 0.1;
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

@end
