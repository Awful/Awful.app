//
//  BookmarksController.m
//  Awful
//
//  Created by Sean Berry on 7/26/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulBookmarksController.h"
#import "AwfulFetchedTableViewControllerSubclass.h"
#import "AwfulAppDelegate.h"
#import "AwfulDataStack.h"
#import "AwfulHTTPClient.h"
#import "AwfulModels.h"

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

- (BOOL)shouldReloadOnViewLoad
{
    return NO;
}

- (void)loadPageNum:(NSUInteger)pageNum
{   
    [self.networkOperation cancel];
    self.isLoading = YES;
    id op = [[AwfulHTTPClient client] listBookmarkedThreadsOnPage:pageNum
                                                          andThen:^(NSError *error, NSArray *threads)
    {
        if (error) {
            [[AwfulAppDelegate instance] requestFailed:error];
        } else {
            if (pageNum == 1) {
                NSArray *bookmarks = [AwfulThread fetchAllMatchingPredicate:@"isBookmarked = YES"];
                [bookmarks setValue:@NO forKey:AwfulThreadAttributes.isBookmarked];
                [threads setValue:@YES forKey:AwfulThreadAttributes.isBookmarked];
                [[AwfulDataStack sharedDataStack] save];
            }
            self.currentPage = pageNum;
        }
        [self finishedRefreshing];
    }];
    self.networkOperation = op;
}

#pragma mark - Table view data source and delegate

- (void)tableView:(UITableView *)tableView
    commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
    forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        AwfulThread *thread = [self.fetchedResultsController objectAtIndexPath:indexPath];
        thread.isBookmarkedValue = NO;
        [[AwfulDataStack sharedDataStack] save];
        self.networkOperation = [[AwfulHTTPClient client] unbookmarkThreadWithID:thread.threadID
                                                                         andThen:^(NSError *error)
        {
            if (!error) return;
            thread.isBookmarkedValue = YES;
            [[AwfulDataStack sharedDataStack] save];
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Could Not Unbookmark"
                                                            message:[error localizedDescription]
                                                           delegate:nil
                                                  cancelButtonTitle:@"Whatever"
                                                  otherButtonTitles:nil];
            [alert show];
        }];
    }
}

- (NSString *)tableView:(UITableView *)tableView
    titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return @"Unbookmark";
}

@end
