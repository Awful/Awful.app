//  AwfulPrivateMessageTableViewController.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPrivateMessageTableViewController.h"
#import "AwfulAlertView.h"
#import "AwfulFetchedResultsControllerDataSource.h"
#import "AwfulHTTPClient.h"
#import "AwfulModels.h"
#import "AwfulNewPMNotifierAgent.h"
#import "AwfulPrivateMessageCell.h"
#import "AwfulPrivateMessageComposeViewController.h"
#import "AwfulPrivateMessageViewController.h"
#import "AwfulSettings.h"
#import "AwfulThreadTag.h"
#import "AwfulThreadTags.h"
#import "AwfulUIKitAndFoundationCategories.h"
#import <SVPullToRefresh/UIScrollView+SVInfiniteScrolling.h>

@interface AwfulPrivateMessageTableViewController () <AwfulFetchedResultsControllerDataSourceDelegate>

@property (strong, nonatomic) UIBarButtonItem *composeItem;
@property (strong, nonatomic) UIBarButtonItem *backItem;

@end

@implementation AwfulPrivateMessageTableViewController
{
    AwfulFetchedResultsControllerDataSource *_dataSource;
}

- (id)initWithManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    if (!(self = [super init])) return nil;
    _managedObjectContext = managedObjectContext;
    self.title = @"Private Messages";
    self.tabBarItem.image = [UIImage imageNamed:@"pm-icon"];
    self.navigationItem.backBarButtonItem = self.backItem;
    self.navigationItem.rightBarButtonItem = self.composeItem;
    self.navigationItem.leftBarButtonItem = self.editButtonItem;
    NSNotificationCenter *noteCenter = [NSNotificationCenter defaultCenter];
    [noteCenter addObserver:self
                   selector:@selector(didGetNewPMCount:)
                       name:AwfulNewPrivateMessagesNotification
                     object:nil];
    return self;
}

- (UIBarButtonItem *)backItem
{
    if (_backItem) return _backItem;
    _backItem = [[UIBarButtonItem alloc] initWithTitle:@"PMs"
                                                 style:UIBarButtonItemStyleBordered
                                                target:nil
                                                action:nil];
    return _backItem;
}

- (UIBarButtonItem *)composeItem
{
    if (_composeItem) return _composeItem;
    _composeItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCompose
                                                                 target:self
                                                                 action:@selector(didTapCompose)];
    return _composeItem;
}

- (void)didTapCompose
{
    AwfulPrivateMessageComposeViewController *compose = [AwfulPrivateMessageComposeViewController new];
    compose.restorationIdentifier = @"Message compose view";
    UINavigationController *nav = [compose enclosingNavigationController];
    nav.restorationIdentifier = @"Message compose nav view";
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)didGetNewPMCount:(NSNotification *)notification
{
    NSNumber *count = notification.userInfo[AwfulNewPrivateMessageCountKey];
    self.tabBarItem.badgeValue = [count integerValue] ? [count stringValue] : nil;
    [self.refreshControl endRefreshing];
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
    [self.tableView awful_hideExtraneousSeparators];
    
    _dataSource = [[AwfulFetchedResultsControllerDataSource alloc] initWithTableView:self.tableView
                                                                     reuseIdentifier:MessageCellIdentifier];
    _dataSource.delegate = self;
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:AwfulPrivateMessage.entityName];
    request.sortDescriptors = @[ [NSSortDescriptor sortDescriptorWithKey:@"sentDate" ascending:NO] ];
    _dataSource.fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                                                               managedObjectContext:self.managedObjectContext
                                                                                 sectionNameKeyPath:nil
                                                                                          cacheName:nil];
    
    self.refreshControl = [UIRefreshControl new];
    [self.refreshControl addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    _dataSource.paused = NO;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if ([self refreshOnAppear]) {
        [self refresh];
    }
}

- (BOOL)refreshOnAppear
{
    if (![AwfulSettings settings].canSendPrivateMessages) return NO;
    if (_dataSource.fetchedResultsController.fetchedObjects.count == 0) return YES;
    NSDate *lastCheckDate = [AwfulNewPMNotifierAgent agent].lastCheckDate;
    if (!lastCheckDate) return YES;
    const NSTimeInterval checkingThreshhold = 10 * 60;
    return (-[lastCheckDate timeIntervalSinceNow] > checkingThreshhold);
}

- (void)refresh
{
    [self.refreshControl beginRefreshing];
    [AwfulNewPMNotifierAgent.agent checkForNewMessages];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
    [super setEditing:editing animated:animated];
    [self.navigationItem setRightBarButtonItem:editing ? nil : self.composeItem
                                      animated:animated];
}

#pragma mark - AwfulFetchedResultsControllerDataSourceDelegate

- (void)configureCell:(AwfulPrivateMessageCell *)cell withObject:(AwfulPrivateMessage *)pm
{
    UIImage *threadTag = [[AwfulThreadTags sharedThreadTags] threadTagNamed:pm.firstIconName];
    if (threadTag) {
        cell.imageView.image = threadTag;
    } else {
        // TODO handle updated thread tags
        cell.imageView.image = [UIImage imageNamed:[AwfulThreadTag emptyPrivateMessageTagImageName]];
    }
    // TODO this is more convoluted than necessary
    if (pm.replied || pm.forwarded || !pm.seen) {
        if (pm.replied) {
            cell.overlayImageView.image = [UIImage imageNamed:@"pmreplied.gif"];
        } else if (pm.forwarded) {
            cell.overlayImageView.image = [UIImage imageNamed:@"pmforwarded.gif"];
        } else if (!pm.seen) {
            cell.overlayImageView.image = [UIImage imageNamed:@"newpm.gif"];
        }
    } else {
        cell.overlayImageView.image = nil;
    }
    cell.textLabel.text = pm.subject;
    cell.detailTextLabel.text = pm.from.username;
}

- (BOOL)canDeleteObject:(AwfulPrivateMessage *)object atIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (void)deleteObject:(AwfulPrivateMessage *)pm
{
    [[AwfulHTTPClient client] deletePrivateMessageWithID:pm.messageID andThen:^(NSError *error) {
        if (error) {
            [AwfulAlertView showWithTitle:@"Could Not Delete Message" error:error buttonTitle:@"OK"];
        } else {
            [pm.managedObjectContext deleteObject:pm];
            NSError *error;
            BOOL ok = [pm.managedObjectContext save:&error];
            if (!ok) {
                NSLog(@"%s error saving after deleting private message %@: %@", __PRETTY_FUNCTION__, pm.messageID, error);
            }
        }
    }];
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulPrivateMessage *pm = [_dataSource.fetchedResultsController objectAtIndexPath:indexPath];
    if (!pm.seen) {
        NSInteger oldValue = self.tabBarItem.badgeValue.integerValue;
        if (oldValue > 0) {
            self.tabBarItem.badgeValue = @(oldValue - 1).stringValue;
        }
    }
    AwfulPrivateMessageViewController *vc = [[AwfulPrivateMessageViewController alloc] initWithPrivateMessage:pm];
    vc.restorationIdentifier = @"Private Message";
    if (self.expandingSplitViewController) {
        UINavigationController *nav = [vc enclosingNavigationController];
        nav.restorationIdentifier = @"Navigation";
        self.expandingSplitViewController.detailViewController = nav;
    } else {
        [self.navigationController pushViewController:vc animated:YES];
    }
}

@end
