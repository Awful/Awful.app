//
//  AwfulPrivateMessagesController.m
//  Awful
//
//  Created by me on 7/20/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPrivateMessage.h"
#import "AwfulPrivateMessageListController.h"
#import "AwfulPrivateMessageViewController.h"
#import "AwfulDataStack.h"
#import "AwfulHTTPClient+PrivateMessages.h"
#import "AwfulThreadCell.h"
#import "AwfulDisclosureIndicatorView.h"
#import "AwfulSettings.h"
#import "AwfulThreadTags.h"
#import "AwfulTheme.h"

//#import "AwfulNewPostComposeController.h"
//#import "AwfulNewPMComposeController.h"
//#import "AwfulPrivateMessageViewReplyComboController.h"
//#import "AwfulThreadTag.h"

@interface AwfulPrivateMessageListController ()

@end

@implementation AwfulPrivateMessageListController

- (NSFetchedResultsController *)createFetchedResultsController
{
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:[AwfulPrivateMessage entityName]];
    request.sortDescriptors = @[
    [NSSortDescriptor sortDescriptorWithKey:@"sent" ascending:NO]
    ];
    return [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                               managedObjectContext:[AwfulDataStack sharedDataStack].context
                                                 sectionNameKeyPath:nil
                                                          cacheName:nil];
}

-(void) viewDidLoad {
    [super viewDidLoad];
    
    self.tableView.rowHeight = 75;
    self.title = @"Private Messages";
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
    req.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"sent" ascending:NO]];
    req.fetchLimit = 1;
    
    /*
    NSArray* newestPM = [ApplicationDelegate.managedObjectContext executeFetchRequest:req error:nil];
    if (newestPM.count == 1) {
        NSDate *date = [[newestPM objectAtIndex:0] sent];
        
        if (-[date timeIntervalSinceNow] > (60*10.0)+60*60) { //dst issue here or something, thread date an hour behind
            return YES;
        }
    }
     */
    return NO;
}

- (void)refresh
{
    [super refresh];
    
    [self.networkOperation cancel];
    self.networkOperation = [[AwfulHTTPClient client]
                             privateMessageListAndThen:^(NSError *error, NSMutableArray *messages) {
                                 self.refreshing = NO;
    }];
     
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString * const Identifier = @"AwfulPrivateMessageCell";
    AwfulThreadCell *cell = [tableView dequeueReusableCellWithIdentifier:Identifier];
    if (!cell) {
        cell = [[AwfulThreadCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:Identifier];
        //UILongPressGestureRecognizer *longPress = [UILongPressGestureRecognizer new];
        //[longPress addTarget:self action:@selector(showThreadActions:)];
        //[cell addGestureRecognizer:longPress];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
            AwfulDisclosureIndicatorView *accessory = [AwfulDisclosureIndicatorView new];
            accessory.cell = cell;
            cell.accessoryView = accessory;
        }
    }
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (void)configureCell:(UITableViewCell *)genericCell atIndexPath:(NSIndexPath *)indexPath
{
    AwfulThreadCell *cell = (AwfulThreadCell *)genericCell;
    AwfulPrivateMessage *pm = [self.fetchedResultsController objectAtIndexPath:indexPath];
    if ([AwfulSettings settings].showThreadTags) {
        cell.imageView.hidden = NO;
        cell.imageView.image = [[AwfulThreadTags sharedThreadTags]
                                threadTagNamed:pm.firstIconName];
        if (!cell.imageView.image && pm.firstIconName) {
            [self updateThreadTag:pm.firstIconName forCellAtIndexPath:indexPath];
        }
        cell.secondaryTagImageView.hidden = YES;
        cell.sticky = NO;
        cell.rating = 0;
    } else {
        cell.imageView.image = nil;
        cell.imageView.hidden = YES;
        cell.secondaryTagImageView.image = nil;
        cell.secondaryTagImageView.hidden = YES;
        cell.sticky = NO;
        cell.closed = NO;
        cell.rating = 0;
    }
    
    AwfulTheme *theme = [AwfulTheme currentTheme];
    cell.textLabel.text = pm.subject;
    cell.textLabel.textColor = theme.threadCellTextColor;
    
    cell.detailTextLabel.text = pm.from;
    cell.detailTextLabel.textColor = theme.threadCellPagesTextColor;
    
    cell.backgroundColor = theme.threadCellBackgroundColor;
    cell.selectionStyle = theme.cellSelectionStyle;
    AwfulDisclosureIndicatorView *disclosure = (AwfulDisclosureIndicatorView *)cell.accessoryView;
    disclosure.color = theme.disclosureIndicatorColor;
    disclosure.highlightedColor = theme.disclosureIndicatorHighlightedColor;
}

- (void)updateThreadTag:(NSString *)threadTagName forCellAtIndexPath:(NSIndexPath *)indexPath
{
    /*
    if (!self.cellsWithoutThreadTags[indexPath]) {
        self.cellsWithoutThreadTags[indexPath] = [NSMutableArray new];
    }
    [self.cellsWithoutThreadTags[indexPath] addObject:threadTagName];
    if (self.listeningForNewThreadTags) return;
    self.listeningForNewThreadTags = YES;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(newThreadTags:)
                                                 name:AwfulNewThreadTagsAvailableNotification
                                               object:nil];
     */
}


-(BOOL) tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    AwfulPrivateMessage* msg = [self.fetchedResultsController objectAtIndexPath:indexPath];
    AwfulPrivateMessageViewController *vc = [[AwfulPrivateMessageViewController alloc] initWithPrivateMessage:msg];
    
    [self.navigationController pushViewController:vc animated:YES];
     
}
/*
-(void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    AwfulPrivateMessageViewReplyComboController *pmView = segue.destinationViewController;
    pmView.privateMessage = (AwfulPM*)sender;
}

-(void) didTapCompose:(UIBarButtonItem*)button {
    UINavigationController *test = [[UINavigationController alloc] initWithRootViewController:[AwfulNewPMComposeController new]];
    test.modalPresentationStyle = UIModalPresentationFormSheet;
    [self.splitViewController presentModalViewController:test animated:YES];
}
 */
@end
