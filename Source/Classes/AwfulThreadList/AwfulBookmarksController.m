//
//  BookmarksController.m
//  Awful
//
//  Created by Sean Berry on 7/26/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulBookmarksController.h"
#import "AwfulPage.h"
#import "AwfulSettings.h"
#import "AwfulTableViewController.h"
#import "AwfulThread.h"
#import "AwfulThreadCell.h"
#import "AwfulThread+AwfulMethods.h"
#import "AwfulLoginController.h"

@implementation AwfulBookmarksController

@synthesize threadCount = _threadCount;

-(void)awakeFromNib
{
    [super awakeFromNib];
        
    self.tableView.delegate = self;
    self.title = @"Bookmarks";
    
        
    [self setEntityName:@"AwfulThread"
              predicate:[NSPredicate predicateWithFormat:@"isBookmarked = YES", self.forum]
                   sort:[NSArray arrayWithObjects:
                         [NSSortDescriptor sortDescriptorWithKey:@"stickyIndex" ascending:NO], 
                         [NSSortDescriptor sortDescriptorWithKey:@"lastPostDate" ascending:NO],
                         nil
                         ]
             sectionKey:nil
     ];

}

#pragma mark - View lifecycle

-(void)viewDidLoad
{
    [super viewDidLoad];
    
    //self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    UIBarButtonItem *back = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"bookmarks.png"]
                                                             style:UIBarButtonItemStyleBordered
                                                            target:nil
                                                            action:nil];
    self.navigationItem.backBarButtonItem = back;
}


-(BOOL)shouldReloadOnViewLoad
{
    //check date on last thread we've got, if older than 10? min reload
    NSFetchRequest *req = [NSFetchRequest fetchRequestWithEntityName:@"AwfulThread"];
    req.predicate = [NSPredicate predicateWithFormat:@"isBookmarked = YES"];
    req.sortDescriptors = [[NSSortDescriptor sortDescriptorWithKey:@"lastPostDate" ascending:NO] wrapInArray];
    req.fetchLimit = 1;
    
    NSArray* newestThread = [ApplicationDelegate.managedObjectContext executeFetchRequest:req error:nil];
    if (newestThread.count == 1) {
        NSDate *date = [[newestThread objectAtIndex:0] lastPostDate];
        
        if (-[date timeIntervalSinceNow] > (60*10.0)+60*60) { //fixme: dst issue here or something, thread date an hour behind
            return YES;
        }
    }
    return NO;
}

-(void)loadPageNum : (NSUInteger)pageNum
{   
    [self.networkOperation cancel];
    self.isLoading = YES;
    self.networkOperation = [[AwfulHTTPClient sharedClient] threadListForBookmarksAtPageNum:pageNum onCompletion:^(NSMutableArray *threads) {
        self.currentPage = pageNum;

        [self finishedRefreshing];
        
    } onError:^(NSError *error) {
        [self finishedRefreshing];
        [ApplicationDelegate requestFailed:error];
    }];
}

-(BOOL)moreThreads
{//fixme
    //if(self.threadCount % 40 == 0 && [self.awfulThreads count] > 0) {
    //    return YES;
    //}
    //return NO;
    return NO;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        
        AwfulThread *thread = [self.fetchedResultsController objectAtIndexPath:indexPath];
        thread.isBookmarkedValue = NO;
        [ApplicationDelegate saveContext];
        
        [self.fetchedResultsController performFetch:nil];
        [self.tableView beginUpdates];
        [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
        [self.tableView endUpdates];
        
        self.networkOperation = [[AwfulHTTPClient sharedClient] removeBookmarkedThread:thread onCompletion:^(void) {
            
        } onError:^(NSError *error) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Failed" message:[error localizedDescription] delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
            [alert show];
        }];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}

-(NSString*) tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
    return @"Remove";
}

@end
