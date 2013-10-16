//  AwfulRapSheetViewController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulRapSheetViewController.h"
#import "AwfulAlertView.h"
#import "AwfulAppDelegate.h"
#import "AwfulHTTPClient.h"
#import "AwfulInfractionCell.h"
#import "AwfulParsing.h"
#import "AwfulUIKitAndFoundationCategories.h"
#import <SVPullToRefresh/SVPullToRefresh.h>

@implementation AwfulRapSheetViewController
{
    NSInteger _mostRecentlyLoadedPage;
    NSMutableOrderedSet *_bans;
}

- (id)initWithUser:(AwfulUser *)user
{
    if (!(self = [super initWithStyle:UITableViewStylePlain])) return nil;
    _user = user;
    self.title = user ? @"Rap Sheet" : @"Leper's Colony";
    self.tabBarItem.image = [UIImage imageNamed:@"lepers_icon"];
    self.modalPresentationStyle = UIModalPresentationFormSheet;
    _bans = [NSMutableOrderedSet new];
    return self;
}

- (id)initWithStyle:(UITableViewStyle)style
{
    return [self initWithUser:nil];
}

- (void)loadView
{
    [super loadView];
    [self.tableView registerClass:[AwfulInfractionCell class] forCellReuseIdentifier:CellIdentifier];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.tableView awful_hideExtraneousSeparators];
    self.refreshControl = [UIRefreshControl new];
    [self.refreshControl addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];
}

- (void)refresh
{
    [self.refreshControl beginRefreshing];
    [self loadPage:1];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if ([self shouldRefreshOnAppear]) {
        [self refresh];
    }
}

- (BOOL)shouldRefreshOnAppear
{
    return _bans.count == 0;
}

- (void)loadPage:(NSUInteger)page
{
    __weak __typeof__(self) weakSelf = self;
    [AwfulHTTPClient.client listBansOnPage:page forUser:self.user.userID andThen:^(NSError *error, NSArray *bans) {
        __typeof__(self) self = weakSelf;
        if (error) {
            [AwfulAlertView showWithTitle:@"Network Error" error:error buttonTitle:@"OK"];
            return;
        }
        _mostRecentlyLoadedPage = page;
        if (page == 1) {
            [_bans removeAllObjects];
            [_bans addObjectsFromArray:bans];
            [self.tableView reloadData];
            if (_bans.count == 0) {
                [self showNothingToSeeView];
            } else {
                [self setUpInfiniteScroll];
            }
        } else {
            NSUInteger oldCount = _bans.count;
            [_bans addObjectsFromArray:bans];
            NSMutableArray *indexPaths = [NSMutableArray new];
            for (NSUInteger i = oldCount; i < _bans.count; i++) {
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
    nothing.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
    nothing.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:nothing];
}

- (void)setUpInfiniteScroll
{
    __weak __typeof__(self) weakSelf = self;
    [self.tableView addInfiniteScrollingWithActionHandler:^{
        __typeof__(self) self = weakSelf;
        [self loadPage:self->_mostRecentlyLoadedPage + 1];
    }];
}

#pragma mark - UITableViewDataSource and UITableViewDelegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _bans.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulInfractionCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    BanParsedInfo *ban = _bans[indexPath.row];
    
    if (ban.banType == AwfulBanTypeProbation) {
        cell.imageView.image = [UIImage imageNamed:@"title-probation"];
    } else if (ban.banType == AwfulBanTypePermaban) {
        cell.imageView.image = [UIImage imageNamed:@"title-permabanned.gif"];
    } else {
        cell.imageView.image = [UIImage imageNamed:@"title-banned.gif"];
    }
    
    cell.textLabel.text = ban.bannedUserName;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ by %@",
                                 [self.banDateFormatter stringFromDate:ban.banDate], ban.requesterUserName];
    cell.reasonLabel.text = ban.banReason;
    
    NSString *banDescription = @"banned";
    if (ban.banType == AwfulBanTypeProbation) banDescription = @"probated";
    else if (ban.banType == AwfulBanTypePermaban) banDescription = @"permabanned";
    NSString *readableBanDate = [self.readableBanDateFormatter stringFromDate:ban.banDate];
    cell.accessibilityLabel = [NSString stringWithFormat:@"%@ was %@ by %@ on %@: “%@”",
                               ban.bannedUserName, banDescription, ban.requesterUserName, readableBanDate, ban.banReason];
    return cell;
}

- (NSDateFormatter *)banDateFormatter
{
    static NSDateFormatter *banDateFormatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        banDateFormatter = [NSDateFormatter new];
        [banDateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"]];
        [banDateFormatter setDateFormat:@"MM/dd/yy HH:mm"];
    });
    return banDateFormatter;
}

- (NSDateFormatter *)readableBanDateFormatter
{
    static NSDateFormatter *readableBanDateFormatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        readableBanDateFormatter = [NSDateFormatter new];
        readableBanDateFormatter.dateStyle = NSDateFormatterMediumStyle;
        readableBanDateFormatter.timeStyle = NSDateFormatterShortStyle;
    });
    return readableBanDateFormatter;
}

static NSString * const CellIdentifier = @"Infraction Cell";

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    BanParsedInfo *ban = _bans[indexPath.row];
    return [AwfulInfractionCell rowHeightWithBanReason:ban.banReason width:CGRectGetWidth(tableView.bounds)];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    BanParsedInfo *ban = _bans[indexPath.row];
    if (!ban.postID) return;
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"awful://posts/%@", ban.postID]];
    [AwfulAppDelegate.instance openAwfulURL:url];
}

@end
