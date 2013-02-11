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
#import "AwfulUser.h"
#import "AwfulDataStack.h"
#import "AwfulHTTPClient+PrivateMessages.h"
#import "AwfulThreadCell.h"
#import "AwfulDisclosureIndicatorView.h"
#import "AwfulSettings.h"
#import "AwfulThreadTags.h"
#import "AwfulTheme.h"
#import "AwfulSplitViewController.h"
#import "AwfulNewPMNotifierAgent.h"
#import "AwfulPMComposerViewController.h"
#import "UIViewController+NavigationEnclosure.h"

//#import "AwfulNewPostComposeController.h"
//#import "AwfulNewPMComposeController.h"
//#import "AwfulPrivateMessageViewReplyComboController.h"
//#import "AwfulThreadTag.h"

@interface AwfulPrivateMessageListController ()

@end

@implementation AwfulPrivateMessageListController

- (id)init {
    self = [super init];
    
    self.title = @"Private Messages";
    self.tabBarItem.image = [UIImage imageNamed:@"pm-icon.png"];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didGetNewPMCount:)
                                                 name:AwfulNewPrivateMessagesNotification
                                               object:nil];
    return self;
    
}
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
    self.tableView.rowHeight = 50;
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

- (void)didGetNewPMCount:(NSNotification*)notification
{
    NSNumber* count = notification.userInfo[kAwfulNewPrivateMessageCountKey];
    self.tabBarItem.badgeValue = [NSString stringWithFormat:@"%@",count];
}

-(BOOL)refreshOnAppear
{
    //check date on last message we've got, if older than 10? min reload
    AwfulPrivateMessage *newestPM = [AwfulPrivateMessage firstSortedBy:
                               @[[NSSortDescriptor sortDescriptorWithKey:@"sent" ascending:NO]]
                               ];
    if (!newestPM || -[newestPM.sent timeIntervalSinceNow] > (10*60*60) ) {  //10 min
        return YES;
    }
    return NO;
}

- (void)refresh
{
    [super refresh];
    
    [self.networkOperation cancel];
    self.networkOperation = [[AwfulHTTPClient client]
                             privateMessageListAndThen:^(NSError *error, NSArray *messages) {
                                 self.refreshing = NO;
    }];
}

- (void)didTapCompose:(id)sender
{
    AwfulPMComposerViewController *composer = [AwfulPMComposerViewController new];
    composer.modalPresentationStyle = UIModalPresentationFormSheet;
    composer.delegate = self;
    
    [self pushOrPresentModalViewController:composer animated:YES];
}

#pragma mark composer delegate
- (void)composerViewController:(AwfulComposerViewController *)composerViewController didSend:(id)post {
    [self dismissModalViewControllerAnimated:YES];
}

- (void)composerViewControllerDidCancel:(AwfulComposerViewController *)composerViewController {
    [self dismissModalViewControllerAnimated:YES];
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
    
    //todo: add accessory icon for forward/replied
    
    /*
    AwfulDisclosureIndicatorView *disclosure = (AwfulDisclosureIndicatorView *)cell.accessoryView;
    disclosure.color = theme.disclosureIndicatorColor;
    disclosure.highlightedColor = theme.disclosureIndicatorHighlightedColor;
     */
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

    AwfulSplitViewController *split = (AwfulSplitViewController *)self.splitViewController;
    if (!split) {
        [self.navigationController pushViewController:vc animated:YES];
    } else {
        UINavigationController *nav = (UINavigationController *)split.viewControllers[1];
        nav.viewControllers = @[ vc ];
        [split.masterPopoverController dismissPopoverAnimated:YES];
    }
    
}
@end
