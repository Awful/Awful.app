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

@interface AwfulLepersViewController ()
@property (nonatomic) uint currentPage;
@end

@implementation AwfulLepersViewController

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
    id op = [[AwfulHTTPClient client] listThreadsInForumWithID:nil
                                                        onPage:pageNum
                                                       andThen:^(NSError *error, NSArray *threads)
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



@end
