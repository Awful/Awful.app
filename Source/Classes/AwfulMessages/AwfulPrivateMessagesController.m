//
//  AwfulPrivateMessagesController.m
//  Awful
//
//  Created by me on 7/20/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPrivateMessagesController.h"
#import "AwfulFetchedTableViewControllerSubclass.h"
#import "AwfulPM.h"
#import "AwfulHTTPClient+PrivateMessages.h"

@interface AwfulPrivateMessagesController ()

@end

@implementation AwfulPrivateMessagesController

- (NSFetchedResultsController *)createFetchedResultsController
{
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:[AwfulPM entityName]];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"sent" ascending:NO]];
    return [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                               managedObjectContext:ApplicationDelegate.managedObjectContext
                                                 sectionNameKeyPath:nil
                                                          cacheName:nil];
}

- (void)refresh
{
    [super refresh];
    [self.networkOperation cancel];
    self.networkOperation = [[AwfulHTTPClient sharedClient] privateMessageListOnCompletion:^(NSMutableArray *messages)
    {
        [self finishedRefreshing];
    } onError:^(NSError *error)
    {
        [self finishedRefreshing];
        [ApplicationDelegate requestFailed:error];
    }];
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    AwfulPM *pm = [self.fetchedResultsController objectAtIndexPath:indexPath];
    cell.textLabel.text = pm.subject;
    cell.detailTextLabel.text = pm.from;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

@end
