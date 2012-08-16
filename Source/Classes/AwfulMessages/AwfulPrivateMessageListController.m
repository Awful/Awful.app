//
//  AwfulPrivateMessagesController.m
//  Awful
//
//  Created by me on 7/20/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPrivateMessageListController.h"
#import "AwfulPM.h"
#import "AwfulHTTPClient+PrivateMessages.h"
#import "AwfulNewPostComposeController.h"
#import "AwfulNewPMComposeController.h"
#import "AwfulPrivateMessageViewReplyComboController.h"
#import "AwfulThreadTag.h"

@interface AwfulPrivateMessageListController ()

@end

@implementation AwfulPrivateMessageListController

-(void) awakeFromNib {
    [self setEntityName:@"AwfulPM"
              predicate:nil
                   sort: [NSArray arrayWithObjects:
                          [NSSortDescriptor sortDescriptorWithKey:@"sent" ascending:NO],
                          nil]
             sectionKey:nil
     ];
}

-(void) viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:(UIBarButtonSystemItemCompose)
                                                                                           target:self
                                                                                           action:@selector(didTapCompose:)
                                              ];
    
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle: @"PMs"
                                                                            style:UIBarButtonItemStyleBordered
                                                                            target:nil
                                                                            action: nil
                                            ];
}

-(BOOL)shouldReloadOnViewLoad
{
    //check date on last thread we've got, if older than 10? min reload
    NSFetchRequest *req = [NSFetchRequest fetchRequestWithEntityName:@"AwfulPM"];
    req.sortDescriptors = [[NSSortDescriptor sortDescriptorWithKey:@"sent" ascending:NO] wrapInArray];
    req.fetchLimit = 1;
    
    NSArray* newestPM = [ApplicationDelegate.managedObjectContext executeFetchRequest:req error:nil];
    if (newestPM.count == 1) {
        NSDate *date = [[newestPM objectAtIndex:0] sent];
        
        if (-[date timeIntervalSinceNow] > (60*10.0)+60*60) { //dst issue here or something, thread date an hour behind
            return YES;
        }
    }
    return NO;
}

- (void)refresh
{
    [super refresh];
    [self.networkOperation cancel];
    self.networkOperation = [[AwfulHTTPClient sharedClient] privateMessageListOnCompletion:^(NSMutableArray *messages) {
        [self finishedRefreshing];
    } 
                                                                                   onError:^(NSError *error) {
        [self finishedRefreshing];
        [ApplicationDelegate requestFailed:error];
    }];
}

-(void) configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    AwfulPM *pm = [self.fetchedResultsController objectAtIndexPath:indexPath];
    cell.textLabel.text = pm.subject;
    cell.detailTextLabel.text = pm.from;
    
    if (pm.threadTag)
        cell.imageView.image = pm.threadTag.image;
    else
        cell.imageView.image = nil;
}

-(BOOL) tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    AwfulPM* msg = [self.fetchedResultsController objectAtIndexPath:indexPath];
    [self performSegueWithIdentifier:@"viewPMSegue" sender:msg];
}

-(void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    AwfulPrivateMessageViewReplyComboController *pmView = segue.destinationViewController;
    pmView.privateMessage = (AwfulPM*)sender;
}

-(void) didTapCompose:(UIBarButtonItem*)button {
    UINavigationController *test = [[UINavigationController alloc] initWithRootViewController:[AwfulNewPMComposeController new]];
    test.modalPresentationStyle = UIModalPresentationFormSheet;
    [self.splitViewController presentModalViewController:test animated:YES];
}
@end
