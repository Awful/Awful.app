//  AwfulBookmarksController.m
//
//  Copyright 2010 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulBookmarksController.h"
#import "AwfulFetchedTableViewControllerSubclass.h"
#import "AwfulAlertView.h"
#import "AwfulHTTPClient.h"
#import "AwfulModels.h"
#import "AwfulThreadCell.h"
#import "NSManagedObject+Awful.h"
#import "UIScrollView+SVInfiniteScrolling.h"

@interface AwfulBookmarksController ()

@property (nonatomic) NSDate *lastRefreshDate;
@property (nonatomic) BOOL showBookmarkColors;

@end


@implementation AwfulBookmarksController

- (id)initWithManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    if (!(self = [super initWithForum:nil])) return nil;
    _managedObjectContext = managedObjectContext;
    self.restorationClass = nil;
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
                                               managedObjectContext:self.managedObjectContext
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
                NSArray *bookmarks = [AwfulThread fetchAllInManagedObjectContext:self.managedObjectContext
                                                               matchingPredicate:@"isBookmarked = YES"];
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
                NSError *error;
                BOOL ok = [self.managedObjectContext save:&error];
                if (!ok) {
                    NSLog(@"%s error loading bookmarks page %tu: %@", __PRETTY_FUNCTION__, pageNum, error);
                }
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
    if ([self.tableView numberOfRowsInSection:0] == 0) return YES;
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

- (void)configureCell:(AwfulThreadCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    [super configureCell:cell atIndexPath:indexPath];
    cell.stickyImageView.image = nil;
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
        self.networkOperation = [[AwfulHTTPClient client] setThreadWithID:thread.threadID
                                                             isBookmarked:NO
                                                                  andThen:^(NSError *error)
        {
            if (!error) return;
            thread.isBookmarkedValue = YES;
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
