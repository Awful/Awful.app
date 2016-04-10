//  RapSheetViewController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "RapSheetViewController.h"
#import "AwfulAppDelegate.h"
#import "AwfulForumsClient.h"
#import "AwfulFrameworkCategories.h"
#import "Awful-Swift.h"

@interface RapSheetViewController ()

@property (strong, nonatomic) UIBarButtonItem *doneItem;
@property (assign, nonatomic) NSInteger mostRecentlyLoadedPage;
@property (strong, nonatomic) NSMutableOrderedSet *punishments;

@end

@implementation RapSheetViewController

- (instancetype)initWithUser:(User *)user
{
    if ((self = [super initWithStyle:UITableViewStylePlain])) {
        _user = user;
        _punishments = [NSMutableOrderedSet new];
        if (user) {
            self.title = @"Rap Sheet";
            self.hidesBottomBarWhenPushed = YES;
            self.modalPresentationStyle = UIModalPresentationFormSheet;
        } else {
            self.title = @"Leper's Colony";
            self.tabBarItem.title = @"Lepers";
            self.tabBarItem.image = [UIImage imageNamed:@"lepers"];
            self.tabBarItem.selectedImage = [UIImage imageNamed:@"lepers-filled"];
        }
    }
    return self;
}

- (instancetype)init
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
    [self.tableView registerClass:[PunishmentCell class] forCellReuseIdentifier:CellIdentifier];
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
    if (self.punishments.count == 0) {
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
    [[AwfulForumsClient client] listPunishmentsOnPage:page forUser:self.user andThen:^(NSError *error, NSArray *punishments) {
        __typeof__(self) self = weakSelf;
        if (error) {
            [self presentViewController:[UIAlertController alertWithNetworkError:error] animated:YES completion:nil];
            return;
        }
        self.mostRecentlyLoadedPage = page;
        if (page == 1) {
            [self.punishments removeAllObjects];
            [self.punishments addObjectsFromArray:punishments];
            [self.tableView reloadData];
            if (self.punishments.count == 0) {
                [self showNothingToSeeView];
            } else {
                [self setUpInfiniteScroll];
            }
        } else {
            NSUInteger oldCount = self.punishments.count;
            [self.punishments addObjectsFromArray:punishments];
            NSMutableArray *indexPaths = [NSMutableArray new];
            for (NSUInteger i = oldCount; i < self.punishments.count; i++) {
                [indexPaths addObject:[NSIndexPath indexPathForRow:i inSection:0]];
            }
            [self.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
        }
        [self.refreshControl endRefreshing];
        [self.infiniteScrollController stop];
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
    self.scrollToLoadMoreBlock = ^{
        __typeof__(self) self = weakSelf;
        [self loadPage:self.mostRecentlyLoadedPage + 1];
    };
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.punishments.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    PunishmentCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    Punishment *punishment = self.punishments[indexPath.row];
    
    {{
        switch (punishment.sentence) {
            case PunishmentSentenceProbation:
                cell.imageView.image = [UIImage imageNamed:@"title-probation"];
                break;
            case PunishmentSentencePermaban:
                cell.imageView.image = [UIImage imageNamed:@"title-permabanned.gif"];
                break;
            case PunishmentSentenceBan:
            case PunishmentSentenceAutoban:
                cell.imageView.image = [UIImage imageNamed:@"title-banned.gif"];
                break;
            case PunishmentSentenceUnknown:
                cell.imageView.image = nil;
                break;
        }
        cell.textLabel.text = punishment.subject.username;
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ by %@", [self.banDateFormatter stringFromDate:punishment.date], punishment.requester.username];
        cell.reasonLabel.text = punishment.reasonHTML;
    }}
    
    {{
        NSString *description = @"banned";
        if (punishment.sentence == PunishmentSentenceProbation) {
            description = @"probated";
        } else if (punishment.sentence == PunishmentSentencePermaban) {
            description = @"permabanned";
        }
        NSString *readableDate = [self.banDateFormatter stringFromDate:punishment.date];
        cell.accessibilityLabel = [NSString stringWithFormat:@"%@ was %@ by %@ on %@: “%@”", punishment.subject.username, description, punishment.requester.username, readableDate, punishment.reasonHTML];
    }}
    
    {{
        Theme *theme = self.theme;
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
    Punishment *punishment = self.punishments[indexPath.row];
    return [PunishmentCell rowHeightWithBanReason:punishment.reasonHTML width:CGRectGetWidth(tableView.bounds)];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    Punishment *punishment = self.punishments[indexPath.row];
    if (punishment.post.postID.length == 0) return;
    NSURL *URL = [NSURL URLWithString:[NSString stringWithFormat:@"awful://posts/%@", punishment.post.postID]];
    [[AwfulAppDelegate instance] openAwfulURL:URL];
    if (self.presentingViewController) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

@end
