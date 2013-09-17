//  AwfulPrivateMessageListController.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPrivateMessageListController.h"
#import "AwfulFetchedTableViewControllerSubclass.h"
#import "AwfulAlertView.h"
#import "AwfulDataStack.h"
#import "AwfulExpandingSplitViewController.h"
#import "AwfulHTTPClient.h"
#import "AwfulModels.h"
#import "AwfulNewPMNotifierAgent.h"
#import "AwfulPrivateMessageCell.h"
#import "AwfulPrivateMessageComposeViewController.h"
#import "AwfulPrivateMessageViewController.h"
#import "AwfulSettings.h"
#import "AwfulThreadTag.h"
#import "AwfulThreadTags.h"
#import <SVPullToRefresh/UIScrollView+SVInfiniteScrolling.h>
#import "UIViewController+NavigationEnclosure.h"

@interface AwfulPrivateMessageListController () <AwfulPrivateMessageComposeViewControllerDelegate>

@property (nonatomic) UIBarButtonItem *composeItem;

@end


@implementation AwfulPrivateMessageListController

- (UIBarButtonItem *)composeItem
{
    if (_composeItem) return _composeItem;
    _composeItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCompose
                                                                 target:self
                                                                 action:@selector(didTapCompose)];
    return _composeItem;
}

#pragma mark - AwfulFetchedTableViewController

- (id)init
{
    if (!(self = [super init])) return nil;
    self.title = @"Private Messages";
    self.tabBarItem.image = [UIImage imageNamed:@"pm-icon"];
    UIBarButtonItem *back = [[UIBarButtonItem alloc] initWithTitle:@"PMs"
                                                             style:UIBarButtonItemStyleBordered
                                                            target:nil action:NULL];
    self.navigationItem.backBarButtonItem = back;
    self.navigationItem.rightBarButtonItem = self.composeItem;
    self.navigationItem.leftBarButtonItem = self.editButtonItem;
    NSNotificationCenter *noteCenter = [NSNotificationCenter defaultCenter];
    [noteCenter addObserver:self selector:@selector(didGetNewPMCount:)
                       name:AwfulNewPrivateMessagesNotification object:nil];
    return self;
}

- (void)didTapCompose
{
    AwfulPrivateMessageComposeViewController *compose;
    compose = [AwfulPrivateMessageComposeViewController new];
    compose.delegate = self;
    [self presentViewController:[compose enclosingNavigationController] animated:YES completion:nil];
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

- (void)loadView
{
    [super loadView];
    [self.tableView registerClass:[AwfulPrivateMessageCell class] forCellReuseIdentifier:MessageCellIdentifier];
}

static NSString * const MessageCellIdentifier = @"Message cell";

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.tableView.rowHeight = 75;
    self.tableView.tableFooterView = [UIView new];
}

- (BOOL)refreshOnAppear
{
    if (![AwfulSettings settings].canSendPrivateMessages) return NO;
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
    [self.navigationItem setRightBarButtonItem:editing ? nil : self.composeItem
                                      animated:animated];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulPrivateMessageCell *cell = [tableView dequeueReusableCellWithIdentifier:MessageCellIdentifier
                                                                    forIndexPath:indexPath];
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (void)configureCell:(AwfulPrivateMessageCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    AwfulPrivateMessage *pm = [self.fetchedResultsController objectAtIndexPath:indexPath];
    UIImage *threadTag = [[AwfulThreadTags sharedThreadTags] threadTagNamed:pm.firstIconName];
    if (threadTag) {
        cell.imageView.image = threadTag;
    } else {
        // TODO handle updated thread tags
        cell.imageView.image = [UIImage imageNamed:[AwfulThreadTag emptyPrivateMessageTagImageName]];
    }
    if (pm.repliedValue || pm.forwardedValue || !pm.seenValue) {
        if (pm.repliedValue) {
            cell.overlayImageView.image = [UIImage imageNamed:@"pmreplied.gif"];
        } else if (pm.forwardedValue) {
            cell.overlayImageView.image = [UIImage imageNamed:@"pmforwarded.gif"];
        } else if (!pm.seenValue) {
            cell.overlayImageView.image = [UIImage imageNamed:@"newpm.gif"];
        }
    } else {
        cell.overlayImageView.image = nil;
    }
    cell.textLabel.text = pm.subject;
    cell.detailTextLabel.text = pm.from.username;
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
    if (self.expandingSplitViewController) {
        UINavigationController *nav = [vc enclosingNavigationController];
        nav.restorationIdentifier = @"Navigation";
        self.expandingSplitViewController.detailViewController = nav;
    } else {
        [self.navigationController pushViewController:vc animated:YES];
    }
}

- (void)tableView:(UITableView *)tableView
    commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
    forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle != UITableViewCellEditingStyleDelete) return;
    AwfulPrivateMessage *message = [self.fetchedResultsController objectAtIndexPath:indexPath];
    if (!message.messageID) {
        NSLog(@"deleting message \"%@\" with no ID", message.subject);
        [message.managedObjectContext deleteObject:message];
        [[AwfulDataStack sharedDataStack] save];
        return;
    }
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
