//
//  AwfulPrivateMessageListController.m
//  Awful
//
//  Created by me on 7/20/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPrivateMessageListController.h"
#import "AwfulFetchedTableViewControllerSubclass.h"
#import "AwfulAlertView.h"
#import "AwfulDataStack.h"
#import "AwfulDisclosureIndicatorView.h"
#import "AwfulHTTPClient.h"
#import "AwfulModels.h"
#import "AwfulNewPMNotifierAgent.h"
#import "AwfulPrivateMessageComposeViewController.h"
#import "AwfulPrivateMessageViewController.h"
#import "AwfulSettings.h"
#import "AwfulSplitViewController.h"
#import "AwfulTheme.h"
#import "AwfulThreadCell.h"
#import "AwfulThreadTags.h"
#import "UIViewController+NavigationEnclosure.h"

@interface AwfulPrivateMessageListController () <AwfulPrivateMessageComposeViewControllerDelegate>

@end


@implementation AwfulPrivateMessageListController

#pragma mark - AwfulFetchedTableViewController

- (id)init
{
    if (!(self = [super init])) return nil;
    self.title = @"Private Messages";
    self.tabBarItem.image = [UIImage imageNamed:@"pm-icon.png"];
    UIBarButtonItem *compose;
    compose = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCompose
                                                            target:self
                                                            action:@selector(didTapCompose)];
    self.navigationItem.rightBarButtonItem = compose;
    self.navigationItem.leftBarButtonItem = self.editButtonItem;
    UIBarButtonItem *back = [[UIBarButtonItem alloc] initWithTitle:@"PMs"
                                                             style:UIBarButtonItemStyleBordered
                                                            target:nil action:NULL];
    self.navigationItem.backBarButtonItem = back;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didGetNewPMCount:)
                                                 name:AwfulNewPrivateMessagesNotification
                                               object:nil];
    return self;
}

- (void)didTapCompose
{
    AwfulPrivateMessageComposeViewController *compose;
    compose = [AwfulPrivateMessageComposeViewController new];
    compose.delegate = self;
    // If the following is true:
    //
    //   1. We're first, or a child of the first, in self.splitViewController.viewControllers.
    //   2. We present a view controller as a page sheet.
    //   3. The split view controller hides its first view controller in the current orientation.
    //
    // Then the presented view controller will be rudely dismissed when the device orientation
    // changes. The workaround is to present from the split view controller itself.
    UIViewController *presenter = self.splitViewController ?: self;
    [presenter presentViewController:[compose enclosingNavigationController] animated:YES
                          completion:nil];
}

- (void)didGetNewPMCount:(NSNotification *)notification
{
    NSNumber *count = notification.userInfo[AwfulNewPrivateMessageCountKey];
    self.tabBarItem.badgeValue = [count integerValue] ? [count stringValue] : nil;
    self.refreshing = NO;
}

- (NSFetchedResultsController *)createFetchedResultsController
{
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:
                               [AwfulPrivateMessage entityName]];
    request.sortDescriptors = @[ [NSSortDescriptor sortDescriptorWithKey:@"sentDate"
                                                               ascending:NO] ];
    NSManagedObjectContext *context = [AwfulDataStack sharedDataStack].context;
    return [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                               managedObjectContext:context
                                                 sectionNameKeyPath:nil cacheName:nil];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.tableView.rowHeight = 75;
}

- (BOOL)refreshOnAppear
{
    if ([self.fetchedResultsController.fetchedObjects count] == 0) return YES;
    NSDate *lastCheckDate = [AwfulNewPMNotifierAgent agent].lastCheckDate;
    if (!lastCheckDate) return YES;
    const NSTimeInterval checkingThreshhold = 10 * 60;
    return (-[lastCheckDate timeIntervalSinceNow] > checkingThreshhold);
}

- (void)refresh
{
    [super refresh];
    [[AwfulNewPMNotifierAgent agent] checkForNewMessages];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
    [super setEditing:editing animated:animated];
    self.navigationItem.leftBarButtonItem.enabled = !editing;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString * const Identifier = @"AwfulPrivateMessageCell";
    AwfulThreadCell *cell = [tableView dequeueReusableCellWithIdentifier:Identifier];
    if (!cell) {
        cell = [[AwfulThreadCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:Identifier];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
            cell.accessoryView = [AwfulDisclosureIndicatorView new];
        }
    }
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (void)configureCell:(UITableViewCell *)genericCell atIndexPath:(NSIndexPath *)indexPath
{
    AwfulThreadCell *cell = (id)genericCell;
    AwfulPrivateMessage *pm = [self.fetchedResultsController objectAtIndexPath:indexPath];
    if ([AwfulSettings settings].showThreadTags) {
        cell.imageView.hidden = NO;
        cell.imageView.image = [[AwfulThreadTags sharedThreadTags]
                                threadTagNamed:pm.firstIconName];
        if (!cell.imageView.image) {
            if (pm.firstIconName) {
                // TODO handle missing thread tag updates
            }
            cell.imageView.image = [UIImage imageNamed:@"empty-pm-tag.png"];
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
    
    cell.detailTextLabel.text = pm.from.username;
    cell.detailTextLabel.textColor = theme.threadCellPagesTextColor;
    
    cell.backgroundColor = theme.threadCellBackgroundColor;
    cell.selectionStyle = theme.cellSelectionStyle;
    
    if (!pm.seenValue) {
        cell.showsUnread = YES;
        cell.unreadCountBadgeView.badgeText = @"New";
    } else {
        cell.showsUnread = NO;
    }
    
    // TODO indicate forwarded/replied/seen
    
    AwfulDisclosureIndicatorView *disclosure = (AwfulDisclosureIndicatorView *)cell.accessoryView;
    disclosure.color = theme.disclosureIndicatorColor;
    disclosure.highlightedColor = theme.disclosureIndicatorHighlightedColor;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulPrivateMessage *pm = [self.fetchedResultsController objectAtIndexPath:indexPath];
    AwfulPrivateMessageViewController *vc;
    vc = [[AwfulPrivateMessageViewController alloc] initWithPrivateMessage:pm];
    AwfulSplitViewController *split = (AwfulSplitViewController *)self.splitViewController;
    if (!split) {
        [self.navigationController pushViewController:vc animated:YES];
    } else {
        UINavigationController *nav = (id)split.viewControllers[1];
        nav.viewControllers = @[ vc ];
        [split.masterPopoverController dismissPopoverAnimated:YES];
    }
}

- (void)tableView:(UITableView *)tableView
    commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
    forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle != UITableViewCellEditingStyleDelete) return;
    AwfulPrivateMessage *message = [self.fetchedResultsController objectAtIndexPath:indexPath];
    [[AwfulHTTPClient client] deletePrivateMessageWithID:message.messageID
                                                 andThen:^(NSError *error)
    {
        if (error) {
            [AwfulAlertView showWithTitle:@"Could Not Delete Message" error:error
                              buttonTitle:@"OK"];
        } else {
            [message.managedObjectContext deleteObject:message];
            [[AwfulDataStack sharedDataStack] save];
        }
    }];
}

#pragma mark - AwfulPrivateMessageComposeViewControllerDelegate

- (void)privateMessageComposeControllerDidSendMessage:(AwfulPrivateMessageComposeViewController *)controller
{
    [controller dismissViewControllerAnimated:YES completion:nil];
}

- (void)privateMessageComposeControllerDidCancel:(AwfulPrivateMessageComposeViewController *)controller
{
    [controller dismissViewControllerAnimated:YES completion:nil];
}

@end
