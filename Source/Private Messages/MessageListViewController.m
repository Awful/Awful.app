//  MessageListViewController.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "MessageListViewController.h"
#import "AwfulFetchedResultsControllerDataSource.h"
#import "AwfulForumsClient.h"
#import "AwfulFrameworkCategories.h"
#import "AwfulModels.h"
#import "AwfulNewMessageChecker.h"
#import "AwfulNewThreadTagObserver.h"
#import "AwfulRefreshMinder.h"
#import "AwfulSettings.h"
#import "AwfulThreadTag.h"
#import "AwfulThreadTagLoader.h"
#import "MessageComposeViewController.h"
#import "MessageViewController.h"
#import <SVPullToRefresh/UIScrollView+SVInfiniteScrolling.h>
#import "Awful-Swift.h"

@interface MessageListViewController () <AwfulFetchedResultsControllerDataSourceDelegate, AwfulComposeTextViewControllerDelegate>

@property (strong, nonatomic) UIBarButtonItem *composeItem;
@property (strong, nonatomic) UIBarButtonItem *backItem;

@property (strong, nonatomic) MessageComposeViewController *composeViewController;

@property (strong, nonatomic) NSDateFormatter *timeFormatter;
@property (strong, nonatomic) NSDateFormatter *dateFormatter;

@property (readonly, strong, nonatomic) NSMutableDictionary *threadTagObservers;

@end

@implementation MessageListViewController
{
    AwfulFetchedResultsControllerDataSource *_dataSource;
}

@synthesize threadTagObservers = _threadTagObservers;

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (id)initWithManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    if ((self = [super initWithStyle:UITableViewStylePlain])) {
        _managedObjectContext = managedObjectContext;
        
        self.title = @"Private Messages";
        self.tabBarItem.title = @"Messages";
        self.tabBarItem.accessibilityLabel = @"Private messages";
        self.tabBarItem.image = [UIImage imageNamed:@"pm-icon"];
        NSInteger unreadMessages = [AwfulNewMessageChecker checker].unreadMessageCount;
        if (unreadMessages > 0) {
            self.tabBarItem.badgeValue = [@(unreadMessages) stringValue];
        }
        self.navigationItem.backBarButtonItem = [UIBarButtonItem awful_emptyBackBarButtonItem];
        self.navigationItem.rightBarButtonItem = self.composeItem;
        self.navigationItem.leftBarButtonItem = self.editButtonItem;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didGetNewPMCount:)
                                                     name:AwfulDidFinishCheckingNewPrivateMessagesNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(settingsDidChange:)
                                                     name:AwfulSettingsDidChangeNotification
                                                   object:nil];
    }
    return self;
}

- (UIBarButtonItem *)composeItem
{
    if (_composeItem) return _composeItem;
    _composeItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCompose target:nil action:nil];
    __weak __typeof__(self) weakSelf = self;
    _composeItem.awful_actionBlock = ^(UIBarButtonItem *item) {
        __typeof__(self) self = weakSelf;
        if (!self.composeViewController) {
            self.composeViewController = [[MessageComposeViewController alloc] initWithRecipient:nil];
            self.composeViewController.restorationIdentifier = @"Message compose view";
            self.composeViewController.delegate = self;
        }
        [self presentViewController:[self.composeViewController enclosingNavigationController] animated:YES completion:nil];
    };
    return _composeItem;
}

- (void)didGetNewPMCount:(NSNotification *)notification
{
    NSNumber *count = notification.userInfo[AwfulNewPrivateMessageCountKey];
    self.tabBarItem.badgeValue = count.integerValue ? count.stringValue : nil;
}

- (void)settingsDidChange:(NSNotification *)notification
{
    if ([notification.userInfo[AwfulSettingsDidChangeSettingKey] isEqualToString:AwfulSettingsKeys.showThreadTags]) {
        [self.tableView reloadData];
    }
}

- (NSDateFormatter *)dateFormatter
{
    if (!_dateFormatter) {
        _dateFormatter = [NSDateFormatter new];
        _dateFormatter.dateStyle = NSDateFormatterShortStyle;
        _dateFormatter.timeStyle = NSDateFormatterNoStyle;
        _dateFormatter.doesRelativeDateFormatting = YES;
    }
    return _dateFormatter;
}

- (NSDateFormatter *)timeFormatter
{
    if (!_timeFormatter) {
        _timeFormatter = [NSDateFormatter new];
        _timeFormatter.dateStyle = NSDateFormatterNoStyle;
        _timeFormatter.timeStyle = NSDateFormatterShortStyle;
    }
    return _timeFormatter;
}

- (void)loadView
{
    [super loadView];
    [self.tableView registerNib:[UINib nibWithNibName:@"MessageCell" bundle:nil] forCellReuseIdentifier:MessageCellIdentifier];
    self.tableView.estimatedRowHeight = 65;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.tableView.estimatedRowHeight = 65;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    
    _dataSource = [[AwfulFetchedResultsControllerDataSource alloc] initWithTableView:self.tableView reuseIdentifier:MessageCellIdentifier];
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

static NSString * const MessageCellIdentifier = @"Message";

- (void)themeDidChange
{
    [super themeDidChange];
    [_composeViewController themeDidChange];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    _dataSource.updatesTableView = YES;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self refreshIfNecessary];
}

- (void)refreshIfNecessary
{
    if (![AwfulSettings sharedSettings].canSendPrivateMessages) return;
    
    if (_dataSource.fetchedResultsController.fetchedObjects.count == 0 || [[AwfulRefreshMinder minder] shouldRefreshPrivateMessagesInbox]) {
        [self refresh];
    }
}

- (IBAction)refresh
{
    [self.refreshControl beginRefreshing];
    __weak __typeof__(self) weakSelf = self;
    [[AwfulForumsClient client] listPrivateMessageInboxAndThen:^(NSError *error, NSArray *messages) {
        __typeof__(self) self = weakSelf;
        [self.refreshControl endRefreshing];
        if (error) {
            [self presentViewController:[UIAlertController alertWithNetworkError:error] animated:YES completion:nil];
        } else {
            [[AwfulRefreshMinder minder] didFinishRefreshingPrivateMessagesInbox];
        }
    }];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
    [super setEditing:editing animated:animated];
    [self.navigationItem setRightBarButtonItem:editing ? nil : self.composeItem
                                      animated:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    _dataSource.updatesTableView = NO;
}

- (NSMutableDictionary *)threadTagObservers
{
    if (!_threadTagObservers) _threadTagObservers = [NSMutableDictionary new];
    return _threadTagObservers;
}

#pragma mark - AwfulFetchedResultsControllerDataSourceDelegate

- (void)configureCell:(MessageCell *)cell withObject:(AwfulPrivateMessage *)pm
{
    if ([AwfulSettings sharedSettings].showThreadTags) {
        cell.showsTag = YES;
        NSString *imageName = pm.threadTag.imageName;
        if (imageName.length > 0) {
            UIImage *image = [AwfulThreadTagLoader imageNamed:imageName];
            if (image) {
                cell.tagImageView.image = image;
            } else {
                cell.tagImageView.image = [AwfulThreadTagLoader emptyPrivateMessageImage];
                
                NSString *messageID = pm.messageID;
                AwfulNewThreadTagObserver *observer = [[AwfulNewThreadTagObserver alloc] initWithImageName:imageName downloadedBlock:^(UIImage *image) {
                    
                    // Make sure the cell represents the same message as when we started.
                    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
                    if (indexPath) {
                        AwfulPrivateMessage *currentMessage = [_dataSource.fetchedResultsController objectAtIndexPath:indexPath];
                        if ([currentMessage.messageID isEqualToString:messageID]) {
                            cell.imageView.image = image;
                        }
                    }
                    [self.threadTagObservers removeObjectForKey:messageID];
                }];
                self.threadTagObservers[messageID] = observer;
            }
        } else {
            cell.tagImageView.image = [AwfulThreadTagLoader emptyPrivateMessageImage];
        }
    } else {
        cell.showsTag = NO;
    }
    
    if (pm.replied) {
        cell.tagOverlayImageView.image = [UIImage imageNamed:@"pmreplied.gif"];
    } else if (pm.forwarded) {
        cell.tagOverlayImageView.image = [UIImage imageNamed:@"pmforwarded.gif"];
    } else if (!pm.seen) {
        cell.tagOverlayImageView.image = [UIImage imageNamed:@"newpm.gif"];
    } else {
        cell.tagOverlayImageView.image = nil;
    }
    
    cell.senderLabel.text = pm.from.username;
    cell.dateLabel.text = [self stringForSentDate:pm.sentDate];
    cell.subjectLabel.text = pm.subject;
    
    NSMutableString *accessibilityLabel = [NSMutableString new];
    [accessibilityLabel appendString:cell.senderLabel.text];
    [accessibilityLabel appendFormat:@". %@", cell.subjectLabel.text];
    [accessibilityLabel appendFormat:@". %@", cell.dateLabel.text];
    cell.accessibilityLabel = accessibilityLabel;
    
    AwfulTheme *theme = self.theme;
    cell.backgroundColor = theme[@"listBackgroundColor"];
    cell.senderLabel.textColor = theme[@"listTextColor"];
    UIFontDescriptor *descriptor = [UIFontDescriptor preferredFontDescriptorWithTextStyle:UIFontTextStyleSubheadline];
    cell.senderLabel.font = [UIFont boldSystemFontOfSize:descriptor.pointSize];
    cell.dateLabel.textColor = theme[@"listTextColor"];
    cell.subjectLabel.textColor = theme[@"listTextColor"];
    cell.separator.backgroundColor = theme[@"listSeparatorColor"];
    UIView *selectedBackgroundView = [UIView new];
    selectedBackgroundView.backgroundColor = theme[@"listSelectedBackgroundColor"];
    cell.selectedBackgroundView = selectedBackgroundView;
}

- (NSString *)stringForSentDate:(NSDate *)date
{
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSCalendarUnit units = NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear;
    NSDateComponents *components = [calendar components:units fromDate:date];
    NSDateComponents *today = [calendar components:units fromDate:[NSDate date]];
    NSDateFormatter *formatter = [components isEqual:today] ? self.timeFormatter : self.dateFormatter;
    return [formatter stringFromDate:date];
}

- (BOOL)canDeleteObject:(AwfulPrivateMessage *)object atIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (void)deleteObject:(AwfulPrivateMessage *)pm
{
    __weak __typeof__(self) weakSelf = self;
    [[AwfulForumsClient client] deletePrivateMessage:pm andThen:^(NSError *error) {
        __typeof__(self) self = weakSelf;
        if (error) {
            [self presentViewController:[UIAlertController alertWithTitle:@"Could Not Delete Message" error:error] animated:YES completion:nil];
        } else {
            [pm.managedObjectContext deleteObject:pm];
            [self decrementBadgeValue];
            NSError *error;
            BOOL ok = [pm.managedObjectContext save:&error];
            if (!ok) {
                NSLog(@"%s error saving after deleting private message %@: %@", __PRETTY_FUNCTION__, pm.messageID, error);
            }
        }
    }];
}

- (void)decrementBadgeValue
{
    NSInteger newValue = self.tabBarItem.badgeValue.integerValue - 1;
    self.tabBarItem.badgeValue = newValue > 0 ? @(newValue).stringValue : nil;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulPrivateMessage *pm = [_dataSource.fetchedResultsController objectAtIndexPath:indexPath];
    if (!pm.seen) {
        [self decrementBadgeValue];
    }
    MessageViewController *messageViewController = [[MessageViewController alloc] initWithPrivateMessage:pm];
    messageViewController.restorationIdentifier = @"Private Message";
    [self showDetailViewController:messageViewController sender:self];
}

#pragma mark - AwfulComposeTextViewControllerDelegate

- (void)composeTextViewController:(ComposeTextViewController *)composeTextViewController
didFinishWithSuccessfulSubmission:(BOOL)success
                  shouldKeepDraft:(BOOL)keepDraft
{
    [self dismissViewControllerAnimated:YES completion:nil];
    if (!keepDraft) {
        _composeViewController = nil;
    }
}

#pragma mark - State preservation and restoration

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super encodeRestorableStateWithCoder:coder];
    [coder encodeObject:_composeViewController forKey:ComposeViewControllerKey];
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super decodeRestorableStateWithCoder:coder];
    _composeViewController = [coder decodeObjectForKey:ComposeViewControllerKey];
    _composeViewController.delegate = self;
}

static NSString * const ComposeViewControllerKey = @"AwfulComposeViewController";

@end
