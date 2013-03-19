//
//  AwfulFavoritesViewController.m
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import "AwfulFavoritesViewController.h"
#import "AwfulDataStack.h"
#import "AwfulDisclosureIndicatorView.h"
#import "AwfulForumCell.h"
#import "AwfulForumsListController.h"
#import "AwfulModels.h"
#import "AwfulSettings.h"
#import "AwfulTheme.h"
#import "AwfulThemingViewController.h"
#import "AwfulThreadListController.h"
#import "NSManagedObject+Awful.h"

@interface CoverView : UIView

@property (readonly, weak, nonatomic) UILabel *noFavoritesLabel;

@property (readonly, weak, nonatomic) UILabel *tapAStarLabel;

@end


@interface AwfulFavoritesViewController ()

@property (copy, nonatomic) NSMutableArray *favoriteForums;

@property (nonatomic) BOOL userUpdate;

@property (readonly, strong, nonatomic) UIBarButtonItem *addButtonItem;

@property (weak, nonatomic) CoverView *coverView;

@end


@implementation AwfulFavoritesViewController

- (id)init
{
    if (!(self = [super initWithNibName:nil bundle:nil])) return nil;
    self.title = @"Favorites";
    self.tabBarItem.image = [UIImage imageNamed:@"favorites-icon.png"];
    _favoriteForums = [NSMutableArray new];
    [self fetchFavoriteForums];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsDidChange:)
                                                 name:AwfulSettingsDidChangeNotification object:nil];
    return self;
}

- (void)fetchFavoriteForums
{
    [self.favoriteForums removeAllObjects];
    NSArray *forumIDs = [AwfulSettings settings].favoriteForums;
    if ([forumIDs count] == 0) return;
    NSArray *forums = [AwfulForum fetchAllMatchingPredicate:@"forumID IN %@", forumIDs];
    [self.favoriteForums addObjectsFromArray:forums];
    [self.favoriteForums sortUsingComparator:^NSComparisonResult(AwfulForum *a, AwfulForum *b) {
        NSUInteger aIndex = [forumIDs indexOfObject:a.forumID];
        NSUInteger bIndex = [forumIDs indexOfObject:b.forumID];
        return [@(aIndex) compare:@(bIndex)];
    }];
}

- (void)settingsDidChange:(NSNotification *)note
{
    if (self.userUpdate) return;
    NSArray *changedSettings = note.userInfo[AwfulSettingsDidChangeSettingsKey];
    if (![changedSettings containsObject:AwfulSettingsKeys.favoriteForums]) return;
    [self fetchFavoriteForums];
    [self.tableView reloadData];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)showNoFavoritesCoverAnimated:(BOOL)animated
{
    self.tableView.scrollEnabled = NO;
    UIView *cover = self.coverView;
    if (animated) {
        [UIView transitionWithView:self.view
                          duration:0.6
                           options:UIViewAnimationOptionTransitionCurlDown
                        animations:^{ [self.view addSubview:cover]; }
                        completion:nil];
    } else {
        [self.view addSubview:cover];
    }
}

- (void)hideNoFavoritesCover
{
    [self.coverView removeFromSuperview];
    self.tableView.scrollEnabled = YES;
}

- (CoverView *)coverView
{
    if (_coverView) return _coverView;
    CoverView *coverView = [[CoverView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:coverView];
    _coverView = coverView;
    return coverView;
}

- (void)updateCoverAndEditButtonAnimated:(BOOL)animated
{
    if ([self.favoriteForums count] > 0) {
        self.navigationItem.rightBarButtonItem = self.editButtonItem;
        [self hideNoFavoritesCover];
    } else {
        self.navigationItem.rightBarButtonItem = nil;
        [self showNoFavoritesCoverAnimated:animated];
    }
}

#pragma mark - UIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    // Hide the cell separators after the last cell.
    self.tableView.tableFooterView = [UIView new];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self updateCoverAndEditButtonAnimated:NO];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
    [super setEditing:editing animated:animated];
    if (!editing) {
        self.userUpdate = YES;
        [AwfulSettings settings].favoriteForums = [self.favoriteForums valueForKey:@"forumID"];
        self.userUpdate = NO;
        [self updateCoverAndEditButtonAnimated:YES];
    }
}

#pragma mark - AwfulTableViewController

- (BOOL)canPullToRefresh
{
    return NO;
}

- (void)retheme
{
    [super retheme];
    self.tableView.separatorColor = [AwfulTheme currentTheme].favoritesSeparatorColor;
    self.view.backgroundColor = [AwfulTheme currentTheme].favoritesBackgroundColor;
    self.coverView.noFavoritesLabel.textColor = [AwfulTheme currentTheme].noFavoritesTextColor;
    self.coverView.tapAStarLabel.textColor = [AwfulTheme currentTheme].noFavoritesTextColor;
}

#pragma mark - UITableViewDataSource and UITableViewDelegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.favoriteForums count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString * const Identifier = @"ForumCell";
    AwfulForumCell *cell = [tableView dequeueReusableCellWithIdentifier:Identifier];
    if (!cell) {
        cell = [[AwfulForumCell alloc] initWithReuseIdentifier:Identifier];
        cell.accessoryView = [AwfulDisclosureIndicatorView new];
    }
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    AwfulForum *forum = self.favoriteForums[indexPath.row];
    cell.textLabel.text = forum.name;
    cell.textLabel.textColor = [AwfulTheme currentTheme].forumCellTextColor;
    cell.selectionStyle = [AwfulTheme currentTheme].cellSelectionStyle;
    AwfulDisclosureIndicatorView *disclosure = (AwfulDisclosureIndicatorView *)cell.accessoryView;
    disclosure.color = [AwfulTheme currentTheme].disclosureIndicatorColor;
    disclosure.highlightedColor = [AwfulTheme currentTheme].disclosureIndicatorHighlightedColor;
}

- (void)tableView:(UITableView *)tableView
  willDisplayCell:(UITableViewCell *)cell
forRowAtIndexPath:(NSIndexPath *)indexPath
{
    cell.backgroundColor = [AwfulTheme currentTheme].forumCellBackgroundColor;
}

- (void)tableView:(UITableView *)tableView
    moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath
    toIndexPath:(NSIndexPath *)destinationIndexPath
{
    [self.favoriteForums exchangeObjectAtIndex:sourceIndexPath.row
                             withObjectAtIndex:destinationIndexPath.row];
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView
           editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView
    commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
    forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        self.userUpdate = YES;
        [self.favoriteForums removeObjectAtIndex:indexPath.row];
        [AwfulSettings settings].favoriteForums = [self.favoriteForums valueForKey:@"forumID"];
        [tableView deleteRowsAtIndexPaths:@[ indexPath ]
                         withRowAnimation:UITableViewRowAnimationAutomatic];
        if (self.editing && [self.favoriteForums count] == 0) {
            [self setEditing:NO animated:YES];
        } else {
            [self updateCoverAndEditButtonAnimated:YES];
        }
        self.userUpdate = NO;
    }
}

- (NSString *)tableView:(UITableView *)tableView
    titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return @"Remove";
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulForum *forum = self.favoriteForums[indexPath.row];
    AwfulThreadListController *threadList = [AwfulThreadListController new];
    threadList.forum = forum;
    [self.navigationController pushViewController:threadList animated:YES];
}

@end


@interface CoverView ()

@property (weak, nonatomic) UILabel *noFavoritesLabel;

@property (weak, nonatomic) UILabel *tapAStarLabel;

@end


@implementation CoverView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
        UILabel *noFavoritesLabel = [UILabel new];
        noFavoritesLabel.text = @"No Favorites";
        noFavoritesLabel.font = [UIFont systemFontOfSize:35];
        noFavoritesLabel.textColor = [UIColor grayColor];
        noFavoritesLabel.backgroundColor = [UIColor clearColor];
        [self addSubview:noFavoritesLabel];
        _noFavoritesLabel = noFavoritesLabel;
        
        UILabel *tapAStarLabel = [UILabel new];
        tapAStarLabel.text = @"Add forums by tapping stars.";
        tapAStarLabel.font = [UIFont systemFontOfSize:16];
        tapAStarLabel.textColor = [UIColor grayColor];
        tapAStarLabel.backgroundColor = [UIColor clearColor];
        [self addSubview:tapAStarLabel];
        _tapAStarLabel = tapAStarLabel;
    }
    return self;
}

- (void)layoutSubviews
{
    [self.noFavoritesLabel sizeToFit];
    [self.tapAStarLabel sizeToFit];
    CGFloat totalHeight = (self.noFavoritesLabel.bounds.size.height + 5 +
                           self.tapAStarLabel.bounds.size.height + 20);
    CGFloat topMargin = (self.bounds.size.height - totalHeight) / 2;
    CGRect noFavoritesFrame = self.noFavoritesLabel.frame;
    noFavoritesFrame.origin.x = CGRectGetMidX(self.bounds) - noFavoritesFrame.size.width / 2;
    noFavoritesFrame.origin.y = topMargin;
    self.noFavoritesLabel.frame = CGRectIntegral(noFavoritesFrame);
    CGRect tapAStarFrame = self.tapAStarLabel.frame;
    tapAStarFrame.origin.x = CGRectGetMidX(self.bounds) - tapAStarFrame.size.width / 2;
    tapAStarFrame.origin.y = CGRectGetMaxY(noFavoritesFrame) + 5;
    self.tapAStarLabel.frame = CGRectIntegral(tapAStarFrame);
}

@end
