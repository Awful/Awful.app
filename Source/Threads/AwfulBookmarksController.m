//
//  AwfulBookmarksController.m
//  Awful
//
//  Created by Sean Berry on 7/26/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulBookmarksController.h"
#import "AwfulFetchedTableViewControllerSubclass.h"
#import "AwfulAlertView.h"
#import "AwfulDataStack.h"
#import "AwfulHTTPClient.h"
#import "AwfulModels.h"
#import "NSManagedObject+Awful.h"
#import "SVPullToRefresh.h"

@interface AwfulBookmarksController ()

@property (nonatomic) NSDate *lastRefreshDate;

@end


@implementation AwfulBookmarksController

- (id)init
{
    if (!(self = [super init])) return nil;
    self.title = @"Bookmarks";
    self.tabBarItem = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemBookmarks
                                                                 tag:0];
    self.tabBarItem.title = @"Bookmarks";
    UIImage *portrait = [UIImage imageNamed:@"bookmarks.png"];
    UIImage *landscapePhone = [UIImage imageNamed:@"bookmarks-landscape.png"];
    UIBarButtonItem *marks = [[UIBarButtonItem alloc] initWithImage:portrait
                                                landscapeImagePhone:landscapePhone
                                                              style:UIBarButtonItemStylePlain
                                                             target:nil
                                                             action:NULL];
    self.navigationItem.backBarButtonItem = marks;
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

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.tableView.tableFooterView = [UIView new];
    self.tableView.tableFooterView.backgroundColor = [UIColor clearColor];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if ([self.fetchedResultsController.fetchedObjects count] < 40) {
        self.tableView.showsInfiniteScrolling = NO;
    }
}

- (void)loadPageNum:(NSUInteger)pageNum
{   
    [self.networkOperation cancel];
    id op = [[AwfulHTTPClient client] listBookmarkedThreadsOnPage:pageNum
                                                          andThen:^(NSError *error, NSArray *threads)
    {
        if (error) {
            [AwfulAlertView showWithTitle:@"Network Error" error:error buttonTitle:@"Drats"];
        } else {
            if (pageNum == 1) {
                NSArray *bookmarks = [AwfulThread fetchAllMatchingPredicate:@"isBookmarked = YES"];
                [bookmarks setValue:@NO forKey:AwfulThreadAttributes.isBookmarked];
                [threads setValue:@YES forKey:AwfulThreadAttributes.isBookmarked];
                self.ignoreUpdates = YES;
                [[AwfulDataStack sharedDataStack] save];
                self.ignoreUpdates = NO;
                self.lastRefreshDate = [NSDate date];
                self.tableView.showsInfiniteScrolling = [threads count] >= 40;
            }
            self.currentPage = pageNum;
        }
        self.refreshing = NO;
    }];
    self.networkOperation = op;
}

- (BOOL)refreshOnAppear
{
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

#pragma mark - Table view data source and delegate

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
            [AwfulAlertView showWithTitle:@"Could Not Unbookmark"
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
