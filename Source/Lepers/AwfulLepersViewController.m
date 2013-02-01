//
//  AwfulLepersViewController.m
//  Awful
//
//  Created by me on 1/29/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulLepersViewController.h"
#import "AwfulLeper.h"
#import "AwfulDataStack.h"
#import "AwfulHTTPClient.h"
#import "AwfulAlertView.h"
#import "AwfulHTTPClient+Lepers.h"
#import "AwfulUser.h"
#import "AwfulLeperCell.h"

@interface AwfulLepersViewController ()
@property (nonatomic) uint currentPage;
@end

@implementation AwfulLepersViewController
- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Lepers' Colony";
}

- (NSFetchedResultsController *)createFetchedResultsController
{
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:[AwfulLeper entityName]];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:AwfulLeperAttributes.date ascending:NO]];
    return [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                               managedObjectContext:[AwfulDataStack sharedDataStack].context
                                                 sectionNameKeyPath:nil
                                                          cacheName:nil];
}

#pragma mark - Table view controller

- (void)refresh
{
    [super refresh];
    [self loadPageNum:1];
}

- (BOOL)canPullForNextPage
{
    return YES;
}

- (void)loadPageNum:(NSUInteger)pageNum
{
    [self.networkOperation cancel];
    id op = [[AwfulHTTPClient client] listBansOnPage:pageNum
                                             andThen:^(NSError *error, NSArray *bans)
             {
                 if (error) {
                     [AwfulAlertView showWithTitle:@"Network Error" error:error buttonTitle:@"OK"];
                 } else {
                     self.currentPage = pageNum;
                 }
                 self.refreshing = NO;
             }];
    self.networkOperation = op;
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString* identifier = [[AwfulLeperCell class] description];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) cell = [AwfulLeperCell new];
    
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    AwfulLeper *leper = [self.fetchedResultsController objectAtIndexPath:indexPath];
    
    AwfulLeperCell* leperCell = (AwfulLeperCell*)cell;
    leperCell.leper = leper;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulLeper* leper = [self.fetchedResultsController objectAtIndexPath:indexPath];
    return [AwfulLeperCell heightWithLeper:leper inTableView:tableView];
}

@end
