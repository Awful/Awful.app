//
//  AwfulPrivateMessageListController.m
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
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
        cell.stickyImageViewOffset = CGSizeMake(1, 2);
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
        if (pm.repliedValue || pm.forwardedValue || !pm.seenValue) {
            cell.stickyImageView.hidden = NO;
            if (pm.repliedValue) {
                cell.stickyImageView.image = [UIImage imageNamed:@"pmreplied.gif"];
            } else if (pm.forwardedValue) {
                cell.stickyImageView.image = [UIImage imageNamed:@"pmforwarded.gif"];
            } else if (!pm.seenValue) {
                cell.stickyImageView.image = [UIImage imageNamed:@"newpm.gif"];
            }
        } else {
            cell.stickyImageView.hidden = YES;
        }
        cell.rating = 0;
    } else {
        cell.imageView.image = nil;
        cell.imageView.hidden = YES;
        cell.secondaryTagImageView.image = nil;
        cell.secondaryTagImageView.hidden = YES;
        cell.stickyImageView.hidden = YES;
        cell.closed = NO;
        cell.rating = 0;
    }
    
    AwfulTheme *theme = [AwfulTheme currentTheme];
    cell.textLabel.text = pm.subject;
    cell.textLabel.textColor = theme.messageListSubjectTextColor;
    
    cell.detailTextLabel.text = pm.from.username;
    cell.detailTextLabel.textColor = theme.messageListUsernameTextColor;
    
    cell.backgroundColor = theme.messageListCellBackgroundColor;
    cell.selectionStyle = theme.cellSelectionStyle;
    cell.showsUnread = NO;
    
    AwfulDisclosureIndicatorView *disclosure = (AwfulDisclosureIndicatorView *)cell.accessoryView;
    disclosure.color = theme.disclosureIndicatorColor;
    disclosure.highlightedColor = theme.disclosureIndicatorHighlightedColor;
}

- (void)tableView:(UITableView *)tableView
  willDisplayCell:(UITableViewCell *)cell
forRowAtIndexPath:(NSIndexPath *)indexPath
{
    cell.backgroundColor = [AwfulTheme currentTheme].messageListCellBackgroundColor;
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

- (void)retheme
{
    [super retheme];
    self.tableView.separatorColor = [AwfulTheme currentTheme].messageListCellSeparatorColor;
    self.view.backgroundColor = [AwfulTheme currentTheme].messageListBackgroundColor;
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
