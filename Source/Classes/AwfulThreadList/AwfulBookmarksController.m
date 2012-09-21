//
//  BookmarksController.m
//  Awful
//
//  Created by Sean Berry on 7/26/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulBookmarksController.h"
#import "AwfulFetchedTableViewControllerSubclass.h"

@implementation AwfulBookmarksController

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    self.title = @"Bookmarks";
    
    [self setEntityType:[AwfulThread class]
              predicate:[NSPredicate predicateWithFormat:@"isBookmarked = YES"]
        sortDescriptors:@[ [NSSortDescriptor sortDescriptorWithKey:@"stickyIndex" ascending:NO],
                           [NSSortDescriptor sortDescriptorWithKey:@"lastPostDate" ascending:NO]]
     sectionNameKeyPath:nil];
}

- (BOOL)shouldReloadOnViewLoad
{
    return NO;
}

- (void)loadPageNum:(NSUInteger)pageNum
{   
    [self.networkOperation cancel];
    self.isLoading = YES;
    self.networkOperation = [[AwfulHTTPClient sharedClient] threadListForBookmarksAtPageNum:pageNum
                                                                               onCompletion:^(id _)
    {
        self.currentPage = pageNum;
        [self finishedRefreshing];
    } onError:^(NSError *error)
    {
        [self finishedRefreshing];
        [ApplicationDelegate requestFailed:error];
    }];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        AwfulThread *thread = [self.fetchedResultsController objectAtIndexPath:indexPath];
        thread.isBookmarkedValue = NO;
        [ApplicationDelegate saveContext];
        
        [self.fetchedResultsController performFetch:nil];
        [self.tableView beginUpdates];
        [self.tableView deleteRowsAtIndexPaths:@[indexPath]
                              withRowAnimation:UITableViewRowAnimationFade];
        [self.tableView endUpdates];
        
        self.networkOperation = [[AwfulHTTPClient sharedClient] removeBookmarkedThread:thread
                                                                          onCompletion:nil
                                                                               onError:^(NSError *error)
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Failed" message:[error localizedDescription] delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
            [alert show];
        }];
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return @"Remove";
}

@end
