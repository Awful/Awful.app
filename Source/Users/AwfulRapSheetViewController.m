//  AwfulRapSheetViewController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulRapSheetViewController.h"
#import "AwfulAlertView.h"
#import "AwfulAppDelegate.h"
#import "AwfulForumsClient.h"
#import "AwfulFrameworkCategories.h"
#import "AwfulModels.h"
#import "AwfulPunishmentCell.h"
#import <SVPullToRefresh/SVPullToRefresh.h>

@interface AwfulRapSheetViewController ()

@property (strong, nonatomic) UIBarButtonItem *doneItem;
@property (assign, nonatomic) NSInteger mostRecentlyLoadedPage;
@property (strong, nonatomic) NSMutableOrderedSet *bans;

@end

@implementation AwfulRapSheetViewController

- (id)initWithUser:(AwfulUser *)user
{
    if ((self = [super initWithStyle:UITableViewStylePlain])) {
        _user = user;
        _bans = [NSMutableOrderedSet new];
        self.title = user ? @"Rap Sheet" : @"Leper's Colony";
        self.navigationItem.backBarButtonItem = [UIBarButtonItem awful_emptyBackBarButtonItem];
        self.tabBarItem.image = [UIImage imageNamed:@"lepers_icon"];
        self.modalPresentationStyle = UIModalPresentationFormSheet;
        self.hidesBottomBarWhenPushed = YES;
    }
    return self;
}

- (id)initWithStyle:(UITableViewStyle)style
{
    return [self initWithUser:nil];
}

- (UIBarButtonItem *)doneItem
{
    if (_doneItem) return _doneItem;
    _doneItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(didTapDone)];
    return _doneItem;
}

- (void)didTapDone
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)loadView
{
    [super loadView];
    [self.tableView registerClass:[AwfulPunishmentCell class] forCellReuseIdentifier:CellIdentifier];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.tableView awful_hideExtraneousSeparators];
    self.refreshControl = [UIRefreshControl new];
    [self.refreshControl addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if (self.presentingViewController && self.navigationController.viewControllers.count == 1) {
        self.navigationItem.rightBarButtonItem = self.doneItem;
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self refreshIfNecessary];
}

- (void)refreshIfNecessary
{
    if (self.bans.count == 0) {
        [self refresh];
    }
}

- (void)refresh
{
    [self.refreshControl beginRefreshing];
    [self loadPage:1];
}

- (void)loadPage:(NSUInteger)page
{
    __weak __typeof__(self) weakSelf = self;
    [[AwfulForumsClient client] listBansOnPage:page forUser:self.user andThen:^(NSError *error, NSArray *bans) {
        __typeof__(self) self = weakSelf;
        if (error) {
            [AwfulAlertView showWithTitle:@"Network Error" error:error buttonTitle:@"OK"];
            return;
        }
        self.mostRecentlyLoadedPage = page;
        if (page == 1) {
            [self.bans removeAllObjects];
            [self.bans addObjectsFromArray:bans];
            [self.tableView reloadData];
            if (self.bans.count == 0) {
                [self showNothingToSeeView];
            } else {
                [self setUpInfiniteScroll];
            }
        } else {
            NSUInteger oldCount = self.bans.count;
            [self.bans addObjectsFromArray:bans];
            NSMutableArray *indexPaths = [NSMutableArray new];
            for (NSUInteger i = oldCount; i < self.bans.count; i++) {
                [indexPaths addObject:[NSIndexPath indexPathForRow:i inSection:0]];
            }
            [self.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
        }
        [self.refreshControl endRefreshing];
        [self.tableView.infiniteScrollingView stopAnimating];
    }];
}

- (void)showNothingToSeeView
{
    UILabel *nothing = [UILabel new];
    nothing.text = @"Nothing to see here…";
    nothing.frame = (CGRect){ .size = self.view.bounds.size };
    nothing.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    nothing.textAlignment = NSTextAlignmentCenter;
    nothing.textColor = self.theme[@"listTextColor"];
    [self.view addSubview:nothing];
}

- (void)setUpInfiniteScroll
{
    __weak __typeof__(self) weakSelf = self;
    [self.tableView addInfiniteScrollingWithActionHandler:^{
        __typeof__(self) self = weakSelf;
        [self loadPage:self.mostRecentlyLoadedPage + 1];
    }];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.bans.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulPunishmentCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    AwfulBan *ban = self.bans[indexPath.row];
    
    {{
        if (ban.punishment == AwfulPunishmentProbation) {
            cell.imageView.image = [UIImage imageNamed:@"title-probation"];
        } else if (ban.punishment == AwfulPunishmentPermaban) {
            cell.imageView.image = [UIImage imageNamed:@"title-permabanned.gif"];
        } else {
            cell.imageView.image = [UIImage imageNamed:@"title-banned.gif"];
        }
        cell.textLabel.text = ban.user.username;
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ by %@", [self.banDateFormatter stringFromDate:ban.date], ban.requester.username];
        cell.reasonLabel.text = ban.reasonHTML;
    }}
    
    {{
        NSString *banDescription = @"banned";
        if (ban.punishment == AwfulPunishmentProbation) {
            banDescription = @"probated";
        } else if (ban.punishment == AwfulPunishmentPermaban) {
            banDescription = @"permabanned";
        }
        NSString *readableBanDate = [self.banDateFormatter stringFromDate:ban.date];
        cell.accessibilityLabel = [NSString stringWithFormat:@"%@ was %@ by %@ on %@: “%@”", ban.user.username, banDescription, ban.requester.username, readableBanDate, ban.reasonHTML];
    }}
    
    {{
        AwfulTheme *theme = self.theme;
        cell.textLabel.textColor = theme[@"listTextColor"];
        cell.detailTextLabel.textColor = theme[@"listSecondaryTextColor"];
        cell.reasonLabel.textColor = theme[@"listTextColor"];
        cell.backgroundColor = theme[@"listBackgroundColor"];
        cell.selectedBackgroundView = [UIView new];
        cell.selectedBackgroundView.backgroundColor = theme[@"listSelectedBackgroundColor"];
    }}
    
    return cell;
}

- (NSDateFormatter *)banDateFormatter
{
    static NSDateFormatter *readableBanDateFormatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        readableBanDateFormatter = [NSDateFormatter new];
		
		// Jan 2, 2003 16:05
        readableBanDateFormatter.dateStyle = NSDateFormatterMediumStyle;
        readableBanDateFormatter.timeStyle = NSDateFormatterShortStyle;
    });
    return readableBanDateFormatter;
}

static NSString * const CellIdentifier = @"Infraction Cell";

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulBan *ban = self.bans[indexPath.row];
    return [AwfulPunishmentCell rowHeightWithBanReason:ban.reasonHTML width:CGRectGetWidth(tableView.bounds)];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulBan *ban = self.bans[indexPath.row];
    if (!ban.post) return;
    NSURL *URL = [NSURL URLWithString:[NSString stringWithFormat:@"awful://posts/%@", ban.post.postID]];
    [[AwfulAppDelegate instance] openAwfulURL:URL];
    if (self.presentingViewController) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

@end
