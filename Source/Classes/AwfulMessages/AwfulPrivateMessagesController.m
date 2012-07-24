//
//  AwfulPrivateMessagesController.m
//  Awful
//
//  Created by me on 7/20/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPrivateMessagesController.h"
#import "AwfulPM.h"
#import "AwfulHTTPClient+PrivateMessages.h"
#import "AwfulComposeController.h"

@interface AwfulPrivateMessagesController ()

@end

@implementation AwfulPrivateMessagesController

-(void) awakeFromNib {
    [self setEntityName:@"AwfulPM"
              predicate:nil
                   sort: [NSArray arrayWithObjects:
                          [NSSortDescriptor sortDescriptorWithKey:@"sent" ascending:NO],
                          nil]
             sectionKey:nil
     ];
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
}

-(BOOL) tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    AwfulComposeController *test = [AwfulComposeController new];
    test.modalPresentationStyle = UIModalPresentationFormSheet;
    [self.splitViewController presentModalViewController:test animated:YES];
}
@end
