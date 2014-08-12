//  AwfulBasementSidebarViewController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulBasementSidebarViewController.h"
#import "AwfulAppDelegate.h"
#import "AwfulAvatarLoader.h"
#import "AwfulBasementHeaderView.h"
#import "AwfulForumsClient.h"
#import "AwfulLoginController.h"
#import "AwfulProfileViewController.h"
#import "AwfulRefreshMinder.h"
#import "AwfulSettings.h"
#import "AwfulSidebarCell.h"

@interface AwfulBasementSidebarViewController () <UITableViewDataSource, UITableViewDelegate>

@property (strong, nonatomic) AwfulBasementHeaderView *headerView;
@property (strong, nonatomic) NSLayoutConstraint *headerHeightConstraint;
@property (strong, nonatomic) UITableView *tableView;

@property (assign, nonatomic) BOOL didAppearAlready;

@property (readonly, strong, nonatomic) AwfulUser *loggedInUser;

@end

@implementation AwfulBasementSidebarViewController

- (void)dealloc
{
    [self stopObservingItems];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(settingsDidChange:)
                                                     name:AwfulSettingsDidChangeNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidBecomeActive:)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userDidLogIn:) name:AwfulUserDidLogInNotification object:nil];
        
        [self refreshIfNecessary];
    }
    return self;
}

- (AwfulUser *)loggedInUser
{
    NSString *userID = [AwfulSettings settings].userID;
    NSString *username = [AwfulSettings settings].username;
    NSManagedObjectContext *managedObjectContext = [AwfulAppDelegate instance].managedObjectContext;
    return [AwfulUser firstOrNewUserWithUserID:userID username:username inManagedObjectContext:managedObjectContext];
}

- (void)loadView
{
    self.view = [UIView new];
    
    AwfulBasementHeaderView *headerView = [AwfulBasementHeaderView new];
    headerView.translatesAutoresizingMaskIntoConstraints = NO;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapHeader)];
    [headerView addGestureRecognizer:tap];
    self.headerView = headerView;
    [self.view addSubview:headerView];
    
    UITableView *tableView = [UITableView new];
    tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView = tableView;
    tableView.dataSource = self;
    tableView.delegate = self;
    [tableView registerClass:[AwfulSidebarCell class] forCellReuseIdentifier:CellIdentifier];
    tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    tableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:tableView];
    
    // Leaving `scrollsToTop` set to its default `YES` prevents the basement's main content view from ever scrolling to top when someone taps the status bar. (If multiple scroll views can scroll to top, none of them actually will.) We set it to `NO` so main content views work as expected. Any sidebar with enough items to make scrolling to top a valuable behaviour is probably ill-conceived anyway.
    tableView.scrollsToTop = NO;
    
    NSDictionary *views = NSDictionaryOfVariableBindings(headerView, tableView);
    [self.view addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[headerView]|"
                                             options:0
                                             metrics:nil
                                               views:views]];
    [self.view addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[tableView]|"
                                             options:0
                                             metrics:nil
                                               views:views]];
    [self.view addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[headerView][tableView]|"
                                             options:0
                                             metrics:nil
                                               views:views]];
    self.headerHeightConstraint = [NSLayoutConstraint constraintWithItem:headerView
                                                               attribute:NSLayoutAttributeHeight
                                                               relatedBy:NSLayoutRelationEqual
                                                                  toItem:nil
                                                               attribute:NSLayoutAttributeNotAnAttribute
                                                              multiplier:1
                                                                constant:0];
    [headerView addConstraint:self.headerHeightConstraint];
}

static NSString * const CellIdentifier = @"Cell";

- (void)updateHeaderView
{
    AwfulBasementHeaderView *headerView = self.headerView;
    headerView.usernameLabel.text = [AwfulSettings settings].username;
    
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation)) {
    #pragma clang diagnostic pop
        
        self.headerHeightConstraint.constant = 64;
        headerView.bottomOffset = 12;
    } else {
        self.headerHeightConstraint.constant = 52;
        headerView.bottomOffset = 5;
    }
    [headerView layoutIfNeeded];
}

- (void)didTapHeader
{
    AwfulProfileViewController *profile = [[AwfulProfileViewController alloc] initWithUser:self.loggedInUser];
    [self presentViewController:[profile enclosingNavigationController] animated:YES completion:nil];
}

- (void)settingsDidChange:(NSNotification *)note
{
    NSString *setting = note.userInfo[AwfulSettingsDidChangeSettingKey];
    if ([setting isEqualToString:AwfulSettingsKeys.username]) {
        [self updateHeaderView];
    } else if ([setting isEqualToString:AwfulSettingsKeys.showAvatars]) {
        [self updateAvatarImageFromCache];
    }
}

- (void)applicationDidBecomeActive:(NSNotification *)note
{
    self.didAppearAlready = NO;
}

- (void)userDidLogIn:(NSNotification *)notification
{
    [self refresh];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    if (![self updateAvatarImageFromCache]) {
        [self refreshIfNecessary];
    }
    [self.tableView awful_hideExtraneousSeparators];
}

- (BOOL)updateAvatarImageFromCache
{
    if ([AwfulSettings settings].showAvatars) {
        return [[AwfulAvatarLoader loader] applyCachedAvatarImageForUser:self.loggedInUser toImageView:self.headerView.avatarImageView];
    } else {
        self.headerView.avatarImageView.image = nil;
        return YES;
    }
}

- (void)themeDidChange
{
    [super themeDidChange];
    AwfulTheme *theme = self.theme;
    AwfulBasementHeaderView *headerView = self.headerView;
    headerView.usernameLabel.textColor = theme[@"basementLabelColor"];
    headerView.backgroundColor = theme[@"basementHeaderBackgroundColor"];
    [self.tableView reloadData];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self updateHeaderView];
    [self selectRowForSelectedItem];
    [self refreshIfNecessary];
    [self.headerView.avatarImageView startAnimating];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // Fixes iOS 7 bug whereby the first cell's separator would never appear.
    if (!self.didAppearAlready) {
        [self.tableView reloadRowsAtIndexPaths:@[ [NSIndexPath indexPathForRow:0 inSection:0] ] withRowAnimation:UITableViewRowAnimationNone];
        self.didAppearAlready = YES;
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [self.headerView.avatarImageView stopAnimating];
}

- (void)refreshIfNecessary
{
    if (![AwfulForumsClient client].loggedIn) return;
    if (![AwfulSettings settings].showAvatars) return;
    
    if ([[AwfulRefreshMinder minder] shouldRefreshLoggedInUser]) {
        [self refresh];
    } else if ([[AwfulRefreshMinder minder] shouldRefreshAvatar]) {
        [self refreshAvatar];
    }
}

- (void)refresh
{
    __weak __typeof__(self) weakSelf = self;
    [[AwfulForumsClient client] learnLoggedInUserInfoAndThen:^(NSError *error, AwfulUser *user) {
        __typeof__(self) self = weakSelf;
        if (error) {
            NSLog(@"%s error refreshing logged-in user's info: %@", __PRETTY_FUNCTION__, error);
        } else {
            [[AwfulRefreshMinder minder] didFinishRefreshingLoggedInUser];
            [self refreshAvatar];
        }
    }];
}

- (void)refreshAvatar
{
    if (![AwfulSettings settings].showAvatars) return;
    
    __weak __typeof__(self) weakSelf = self;
    [[AwfulAvatarLoader loader] applyAvatarImageForUser:self.loggedInUser toImageViewAfterCompletion:^UIImageView *(BOOL modified, NSError *error) {
        __typeof__(self) self = weakSelf;
        if (error) {
            NSLog(@"%s error loading avatar image: %@", __PRETTY_FUNCTION__, error);
        } else {
            [[AwfulRefreshMinder minder] didFinishRefreshingAvatar];
            if (modified && [self isViewLoaded]) {
                return self.headerView.avatarImageView;
            }
        }
        return nil;
    }];
}

- (void)setItems:(NSArray *)items
{
    if (_items == items) return;
    [self stopObservingItems];
    _items = [items copy];
    if (![_items containsObject:self.selectedItem]) {
        self.selectedItem = _items[0];
    }
    [self.tableView reloadData];
    NSIndexSet *indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, _items.count)];
    [_items addObserver:self toObjectsAtIndexes:indexes forKeyPath:@"badgeValue" options:0 context:KVOContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context != KVOContext) {
        return [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
    if ([keyPath isEqualToString:@"badgeValue"]) {
        UITabBarItem *tabBarItem = object;
        NSUInteger i = [self.items indexOfObject:tabBarItem];
        [self.tableView reloadRowsAtIndexPaths:@[ [NSIndexPath indexPathForRow:i inSection:0] ]
                              withRowAnimation:UITableViewRowAnimationNone];
    }
}

- (void)stopObservingItems
{
    NSIndexSet *indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, _items.count)];
    [_items removeObserver:self fromObjectsAtIndexes:indexes forKeyPath:@"badgeValue" context:KVOContext];
}

static void * KVOContext = &KVOContext;

- (void)setSelectedItem:(UITabBarItem *)selectedItem
{
    if (_selectedItem == selectedItem) return;
    _selectedItem = selectedItem;
    if ([self isViewLoaded]) {
        [self selectRowForSelectedItem];
    }
}

- (void)selectRowForSelectedItem
{
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:[self.items indexOfObject:self.selectedItem] inSection:0];
    [self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [self updateHeaderView];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulSidebarCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    UITabBarItem *item = self.items[indexPath.row];
    cell.imageView.image = item.image;
    cell.textLabel.text = item.title;
    
    AwfulTheme *theme = self.theme;
    cell.textLabel.textColor = theme[@"basementLabelColor"];
    if (item.badgeValue.length > 0) {
        cell.badgeLabel.textColor = theme[@"basementBadgeColor"];
        cell.badgeLabel.text = item.badgeValue;
        [cell.badgeLabel sizeToFit];
    } else {
        cell.badgeLabel = nil;
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView willDisplayCell:(AwfulSidebarCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    cell.backgroundColor = [UIColor clearColor];
    cell.separatorView.backgroundColor = self.theme[@"basementSeparatorColor"];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITabBarItem *item = self.items[indexPath.row];
    [self.delegate sidebar:self didSelectItem:item];
}

@end
