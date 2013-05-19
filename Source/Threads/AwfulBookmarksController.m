//
//  AwfulBookmarksController.m
//  Awful
//
//  Copyright 2010 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import "AwfulBookmarksController.h"
#import "AwfulFetchedTableViewControllerSubclass.h"
#import "AwfulAlertView.h"
#import "AwfulDataStack.h"
#import "AwfulHTTPClient.h"
#import "AwfulModels.h"
#import "AwfulTheme.h"
#import "AwfulThreadCell.h"
#import "NSManagedObject+Awful.h"
#import "UIScrollView+SVInfiniteScrolling.h"

@interface AwfulBookmarksController ()

@property (nonatomic) NSDate *lastRefreshDate;
@property (nonatomic) BOOL showBookmarkColors;

@end


@implementation AwfulBookmarksController

- (id)init
{
    if (!(self = [super init])) return nil;
    self.title = @"Bookmarks";
    self.tabBarItem.image = [UIImage imageNamed:@"bookmarks.png"];
    UIImage *portrait = [UIImage imageNamed:@"bookmarks.png"];
    UIImage *landscapePhone = [UIImage imageNamed:@"bookmarks-landscape.png"];
    UIBarButtonItem *marks = [[UIBarButtonItem alloc] initWithImage:portrait
                                                landscapeImagePhone:landscapePhone
                                                              style:UIBarButtonItemStylePlain
                                                             target:nil
                                                             action:NULL];
    self.navigationItem.backBarButtonItem = marks;
    self.navigationItem.rightBarButtonItem = nil;
    return self;
}

- (NSFetchedResultsController *)createFetchedResultsController
{
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:[AwfulThread entityName]];
    request.predicate = [NSPredicate predicateWithFormat:@"isBookmarked = YES"];
    request.sortDescriptors = @[
        [NSSortDescriptor sortDescriptorWithKey:@"lastPostDate" ascending:NO]
    ];
    return [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                               managedObjectContext:[AwfulDataStack sharedDataStack].context
                                                 sectionNameKeyPath:nil
                                                          cacheName:nil];
}

- (void)loadPageNum:(NSUInteger)pageNum
{   
    [self.networkOperation cancel];
    __block id op;
    op = [[AwfulHTTPClient client] listBookmarkedThreadsOnPage:pageNum
                                                       andThen:^(NSError *error, NSArray *threads)
    {
        if (![self.networkOperation isEqual:op]) return;
        if (error) {
            [AwfulAlertView showWithTitle:@"Network Error" error:error buttonTitle:@"OK"];
        } else {
            if (pageNum == 1) {
                NSArray *bookmarks = [AwfulThread fetchAllMatchingPredicate:@"isBookmarked = YES"];
                [bookmarks setValue:@NO forKey:AwfulThreadAttributes.isBookmarked];
                [threads setValue:@YES forKey:AwfulThreadAttributes.isBookmarked];
                BOOL wasShowingBookmarkColors = self.showBookmarkColors;
                self.showBookmarkColors = NO;
                for (NSNumber *star in [bookmarks valueForKey:AwfulThreadAttributes.starCategory]) {
                    NSInteger category = [star integerValue];
                    if (category == AwfulStarCategoryRed || category == AwfulStarCategoryYellow) {
                        self.showBookmarkColors = YES;
                        break;
                    }
                }
                self.ignoreUpdates = YES;
                [[AwfulDataStack sharedDataStack] save];
                self.ignoreUpdates = NO;
                self.lastRefreshDate = [NSDate date];
                if (self.showBookmarkColors != wasShowingBookmarkColors) {
                    [self.tableView reloadData];
                }
            }
            self.currentPage = pageNum;
            self.tableView.showsInfiniteScrolling = [threads count] >= 40;
        }
        self.refreshing = NO;
    }];
    self.networkOperation = op;
}

- (BOOL)refreshOnAppear
{
    if (![AwfulHTTPClient client].reachable) return NO;
    if (!self.lastRefreshDate) return YES;
    return [[NSDate date] timeIntervalSinceDate:self.lastRefreshDate] > 60 * 10;
}

- (NSDate *)lastRefreshDate
{
    return [[NSUserDefaults standardUserDefaults] objectForKey:kLastBookmarksRefreshDate];
}

- (void)setLastRefreshDate:(NSDate *)lastRefreshDate
{
    [[NSUserDefaults standardUserDefaults] setObject:lastRefreshDate
                                              forKey:kLastBookmarksRefreshDate];
}

static NSString * const kLastBookmarksRefreshDate = @"com.awfulapp.Awful.LastBookmarksRefreshDate";

#pragma mark - AwfulTableViewController

- (void)configureCell:(UITableViewCell *)genericCell atIndexPath:(NSIndexPath *)indexPath
{
    [super configureCell:genericCell atIndexPath:indexPath];
    AwfulThreadCell *cell = (id)genericCell;
    if (!cell.showsUnread) {
        cell.unreadCountBadgeView.badgeText = @"∞";
        cell.unreadCountBadgeView.on = YES;
        cell.showsUnread = YES;
    }
    if (!self.showBookmarkColors) {
        AwfulTheme *theme = [AwfulTheme currentTheme];
        cell.unreadCountBadgeView.badgeColor = theme.threadListUnreadBadgeBlueColor;
        cell.unreadCountBadgeView.offBadgeColor = theme.threadListUnreadBadgeBlueOffColor;
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (void)tableView:(UITableView *)tableView
    commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
    forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        AwfulThread *thread = [self.fetchedResultsController objectAtIndexPath:indexPath];
        thread.isBookmarkedValue = NO;
        [[AwfulDataStack sharedDataStack] save];
        self.networkOperation = [[AwfulHTTPClient client] setThreadWithID:thread.threadID
                                                             isBookmarked:NO
                                                                  andThen:^(NSError *error)
        {
            if (!error) return;
            thread.isBookmarkedValue = YES;
            [[AwfulDataStack sharedDataStack] save];
            [AwfulAlertView showWithTitle:@"Error Removing Bbookmark"
                                    error:error
                              buttonTitle:@"Whatever"];
        }];
    }
}

- (NSString *)tableView:(UITableView *)tableView
    titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return @"Unbookmark";
}

@end
