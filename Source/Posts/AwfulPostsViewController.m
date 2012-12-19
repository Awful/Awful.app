//
//  AwfulPostsViewController.m
//  Awful
//
//  Created by Sean Berry on 7/29/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPostsViewController.h"
#import "AwfulActionSheet.h"
#import "AwfulAlertView.h"
#import "AwfulDataStack.h"
#import "AwfulHTTPClient.h"
#import "AwfulImagePreviewViewController.h"
#import "AwfulModels.h"
#import "AwfulPageBar.h"
#import "AwfulPostsView.h"
#import "AwfulPullToRefreshControl.h"
#import "AwfulReplyViewController.h"
#import "AwfulSettings.h"
#import "AwfulSpecificPageController.h"
#import "AwfulTheme.h"
#import "NSFileManager+UserDirectories.h"
#import "NSManagedObject+Awful.h"
#import "NSString+CollapseWhitespace.h"
#import "NSURL+QueryDictionary.h"
#import <QuartzCore/QuartzCore.h>
#import "SVProgressHUD.h"
#import "UINavigationItem+TwoLineTitle.h"
#import "UIViewController+NavigationEnclosure.h"

@interface TopBarView : UIView

@property (readonly, weak, nonatomic) UIButton *goToForumButton;

@property (readonly, weak, nonatomic) UIButton *loadReadPostsButton;

@property (readonly, weak, nonatomic) UIButton *scrollToBottomButton;

@end


@interface AwfulPostsViewController () <AwfulPostsViewDelegate, UIPopoverControllerDelegate,
                                        AwfulSpecificPageControllerDelegate,
                                        NSFetchedResultsControllerDelegate,
                                        AwfulReplyViewControllerDelegate,
                                        UIScrollViewDelegate>

@property (nonatomic) NSFetchedResultsController *fetchedResultsController;

@property (nonatomic) NSInteger hiddenPosts;

@property (weak, nonatomic) NSOperation *networkOperation;

@property (weak, nonatomic) AwfulPageBar *pageBar;

@property (nonatomic) AwfulSpecificPageController *specificPageController;

@property (weak, nonatomic) AwfulPostsView *postsView;

@property (weak, nonatomic) AwfulPullToRefreshControl *pullUpToRefreshControl;

@property (weak, nonatomic) TopBarView *topBar;

@property (copy, nonatomic) NSString *advertisementHTML;

@property (nonatomic) BOOL didJustMarkAsReadToHere;

- (void)showThreadActionsFromRect:(CGRect)rect inView:(UIView *)view;

- (void)showActionsForPost:(AwfulPost *)post fromRect:(CGRect)rect inView:(UIView *)view;

@property (nonatomic) NSDateFormatter *regDateFormatter;

@property (nonatomic) NSDateFormatter *postDateFormatter;

@property (nonatomic) UIPopoverController *popover;

@property (nonatomic) BOOL markingPostsAsBeenSeen;

@property (nonatomic) BOOL observingScrollViewSize;

@property (nonatomic) NSMutableArray *cachedUpdatesWhileScrolling;

@property (nonatomic) CGPoint lastContentOffset;

@property (nonatomic) BOOL scrollingUp;

@property (copy, nonatomic) NSString *jumpToPostAfterLoad;

@end


@implementation AwfulPostsViewController

- (id)init
{
    if (!(self = [super initWithNibName:nil bundle:nil])) return nil;
    self.hidesBottomBarWhenPushed = YES;
    NSNotificationCenter *noteCenter = [NSNotificationCenter defaultCenter];
    [noteCenter addObserver:self
                   selector:@selector(currentThemeChanged:)
                       name:AwfulThemeDidChangeNotification
                     object:nil];
    [noteCenter addObserver:self
                   selector:@selector(settingChanged:)
                       name:AwfulSettingsDidChangeNotification
                     object:nil];
    return self;
}

- (void)dealloc
{
    NSNotificationCenter *noteCenter = [NSNotificationCenter defaultCenter];
    [noteCenter removeObserver:self name:AwfulSettingsDidChangeNotification object:nil];
    [noteCenter removeObserver:self name:AwfulThemeDidChangeNotification object:nil];
    [self stopObserving];
    self.postsView.scrollView.delegate = nil;
}

- (void)currentThemeChanged:(NSNotification *)note
{
    if (![self isViewLoaded]) return;
    [self retheme];
}

- (void)settingChanged:(NSNotification *)note
{
    if (![self isViewLoaded]) return;
    NSArray *importantKeys = @[
        AwfulSettingsKeys.highlightOwnMentions,
        AwfulSettingsKeys.highlightOwnQuotes,
        AwfulSettingsKeys.showAvatars,
        AwfulSettingsKeys.showImages,
        AwfulSettingsKeys.username,
        AwfulSettingsKeys.yosposStyle
    ];
    NSArray *keys = note.userInfo[AwfulSettingsDidChangeSettingsKey];
    if ([keys firstObjectCommonWithArray:importantKeys]) [self configurePostsViewSettings];
}

- (void)setThread:(AwfulThread *)thread
{
    if ([_thread isEqual:thread]) return;
    _thread = thread;
    _threadID = [thread.threadID copy];
    self.title = [thread.title stringByCollapsingWhitespace];
    [self updatePageBar];
    [self configurePostsViewSettings];
    [self updateFetchedResultsController];
}

- (void)setThreadID:(NSString *)threadID
{
    if (threadID == _threadID) return;
    self.thread = [AwfulThread firstMatchingPredicate:@"threadID = %@", threadID];
    if (!self.thread) {
        _threadID = [threadID copy];
    }
}

- (NSArray *)posts
{
    return self.fetchedResultsController.fetchedObjects;
}

static NSURL* StylesheetURLForForumWithID(NSString *forumID)
{
    NSMutableArray *listOfFilenames = [@[ @"posts-view.css" ] mutableCopy];
    if (forumID) {
        NSString *filename = [NSString stringWithFormat:@"posts-view-%@.css", forumID];
        if ([forumID isEqualToString:@"219"]) {
            AwfulYOSPOSStyle style = [AwfulSettings settings].yosposStyle;
            if (style == AwfulYOSPOSStyleAmber) filename = @"posts-view-219-amber.css";
            else if (style == AwfulYOSPOSStyleNone) filename = nil;
        }
        if (filename) [listOfFilenames insertObject:filename atIndex:0];
    }
    NSURL *documents = [[NSFileManager defaultManager] documentDirectory];
    for (NSString *filename in listOfFilenames) {
        NSURL *url = [documents URLByAppendingPathComponent:filename];
        if ([url checkResourceIsReachableAndReturnError:NULL]) return url;
    }
    for (NSString *filename in listOfFilenames) {
        NSURL *url = [[NSBundle mainBundle] URLForResource:filename
                                             withExtension:nil];
        if ([url checkResourceIsReachableAndReturnError:NULL]) return url;
    }
    return nil;
}

- (void)updateFetchedResultsController
{
    if (!self.thread || self.currentPage < 1) {
        self.fetchedResultsController.delegate = nil;
        self.fetchedResultsController = nil;
        return;
    }
    NSFetchRequest *request = self.fetchedResultsController.fetchRequest;
    if (!request) {
        request = [NSFetchRequest fetchRequestWithEntityName:[AwfulPost entityName]];
        [request setSortDescriptors:@[
            [NSSortDescriptor sortDescriptorWithKey:AwfulPostAttributes.threadIndex ascending:YES]
        ]];
        NSManagedObjectContext *context = self.thread.managedObjectContext;
        NSFetchedResultsController *controller;
        controller = [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                                         managedObjectContext:context
                                                           sectionNameKeyPath:nil
                                                                    cacheName:nil];
        controller.delegate = self;
        self.fetchedResultsController = controller;
    }
    request.predicate = [NSPredicate predicateWithFormat:@"thread == %@ AND threadPage = %d",
                         self.thread, self.currentPage];
    NSError *error;
    BOOL ok = [self.fetchedResultsController performFetch:&error];
    if (!ok) {
        NSLog(@"error fetching posts: %@", error);
    }
}

- (void)updatePullForNextPageLabel
{
    AwfulPullToRefreshControl *refresh = self.pullUpToRefreshControl;
    if (self.thread.numberOfPagesValue > self.currentPage) {
        [refresh setTitle:@"Pull for next page…" forState:UIControlStateNormal];
        [refresh setTitle:@"Release for next page…" forState:UIControlStateSelected];
        [refresh setTitle:@"Loading next page…" forState:AwfulControlStateRefreshing];
    } else {
        [refresh setTitle:@"Pull to refresh…" forState:UIControlStateNormal];
        [refresh setTitle:@"Release to refresh…" forState:UIControlStateSelected];
        [refresh setTitle:@"Refreshing…" forState:AwfulControlStateRefreshing];
    }
}

- (AwfulPostsView *)postsView
{
    if (!_postsView) [self view];
    return _postsView;
}

- (void)updateLoadingMessage
{
    if (self.currentPage == AwfulPageLast) {
        self.postsView.loadingMessage = @"Loading last page";
    } else if (self.currentPage == AwfulPageNextUnread) {
        self.postsView.loadingMessage = @"Loading unread posts";
    } else if ([self.fetchedResultsController.fetchedObjects count] == 0) {
        self.postsView.loadingMessage = [NSString stringWithFormat:
                                         @"Loading page %d", self.currentPage];
    } else {
        self.postsView.loadingMessage = nil;
    }
}

- (void)updateEndMessage
{
    if (self.currentPage > 0 && self.currentPage >= self.thread.numberOfPagesValue) {
        self.postsView.endMessage = @"End of the thread";
    } else {
        self.postsView.endMessage = nil;
    }
}

- (void)setHiddenPosts:(NSInteger)hiddenPosts
{
    if (_hiddenPosts == hiddenPosts) return;
    _hiddenPosts = hiddenPosts;
    [self updateTopBar];
}

- (void)loadPage:(NSInteger)page
{
    [self.networkOperation cancel];
    self.jumpToPostAfterLoad = nil;
    NSInteger oldPage = self.currentPage;
    self.currentPage = page;
    BOOL refreshingSamePage = page > 0 && page == oldPage;
    if (!refreshingSamePage) {
        [self updateFetchedResultsController];
        [self updateLoadingMessage];
        [self updatePageBar];
        [self updateTopBar];
        [self updateEndMessage];
        self.pullUpToRefreshControl.refreshing = NO;
        [self updatePullForNextPageLabel];
        UIEdgeInsets inset = self.postsView.scrollView.contentInset;
        [self.postsView.scrollView setContentOffset:CGPointMake(0, -inset.top) animated:NO];
        self.advertisementHTML = nil;
        self.hiddenPosts = 0;
        [self.postsView reloadData];
    }
    // This blockSelf exists entirely so we capture self in the block, which allows its use while
    // debugging. Otherwise lldb/gdb don't know anything about "self".
    __block AwfulPostsViewController *blockSelf = self;
    id op = [[AwfulHTTPClient client] listPostsInThreadWithID:self.threadID
                                                       onPage:page
                                                      andThen:^(NSError *error, NSArray *posts,
                                                                NSUInteger firstUnreadPost,
                                                                NSString *advertisementHTML)
    {
        // Since we load cached pages where possible, things can get out of order if we change
        // pages quickly. If the callback comes in after we've moved away from the requested page,
        // just don't bother going any further. We have the data for later.
        if (page != self.currentPage) return;
        BOOL wasLoading = !!self.postsView.loadingMessage;
        if (error) {
            if (wasLoading) {
                self.postsView.loadingMessage = nil;
                if (![[self.pageBar.jumpToPageButton titleForState:UIControlStateNormal] length]) {
                    if (self.thread.numberOfPagesValue > 0) {
                        NSString *title = [NSString stringWithFormat:@"Page ? of %@",
                                           self.thread.numberOfPages];
                        [self.pageBar.jumpToPageButton setTitle:title
                                                       forState:UIControlStateNormal];
                    } else {
                        [self.pageBar.jumpToPageButton setTitle:@"Page ? of ?"
                                                       forState:UIControlStateNormal];
                    }
                }
            }
            // Poor man's offline mode.
            if (!wasLoading && !refreshingSamePage
                && [error.domain isEqualToString:NSURLErrorDomain]) {
                return;
            }
            [AwfulAlertView showWithTitle:@"Could Not Load Page" error:error buttonTitle:@"OK"];
            self.pullUpToRefreshControl.refreshing = NO;
            return;
        }
        if ([posts count] > 0) {
            self.thread = [[posts lastObject] thread];
            self.currentPage = [[posts lastObject] threadPageValue];
        }
        self.advertisementHTML = advertisementHTML;
        if (page == AwfulPageNextUnread && firstUnreadPost != NSNotFound) {
            self.hiddenPosts = firstUnreadPost;
        }
        if (!self.fetchedResultsController) [self updateFetchedResultsController];
        if (wasLoading) {
            [self.postsView reloadData];
        } else {
            [self.postsView reloadAdvertisementHTML];
        }
        [self updateLoadingMessage];
        [self updatePageBar];
        [self updateTopBar];
        [self updateEndMessage];
        [self updatePullForNextPageLabel];
        if (self.jumpToPostAfterLoad) {
            [self jumpToPostWithID:self.jumpToPostAfterLoad];
            self.jumpToPostAfterLoad = nil;
        } else if (wasLoading) {
            CGFloat inset = self.postsView.scrollView.contentInset.top;
            [self.postsView.scrollView setContentOffset:CGPointMake(0, -inset) animated:NO];
        }
        [blockSelf markPostsAsBeenSeen];
    }];
    self.networkOperation = op;
}

- (void)jumpToPostWithID:(NSString *)postID
{
    if (self.postsView.loadingMessage) {
        self.jumpToPostAfterLoad = postID;
    } else {
        if (self.hiddenPosts > 0) {
            NSUInteger i = [self.posts indexOfObjectPassingTest:^BOOL(AwfulPost *post,
                                                                      NSUInteger _, BOOL *__)
            {
                return [post.postID isEqualToString:postID];
            }];
            if (i < (NSUInteger)self.hiddenPosts) [self showHiddenSeenPosts];
        }
        [self.postsView jumpToElementWithID:postID];
    }
}

- (void)markPostsAsBeenSeen
{
    if (self.didJustMarkAsReadToHere) {
        self.didJustMarkAsReadToHere = NO;
        return;
    }
    AwfulPost *lastPost = [[self.fetchedResultsController fetchedObjects] lastObject];
    if (!lastPost || lastPost.beenSeenValue) return;
    [self markPostsAsBeenSeenUpToPost:lastPost];
}

- (void)markPostsAsBeenSeenUpToPost:(AwfulPost *)post
{
    self.markingPostsAsBeenSeen = YES;
    NSArray *posts = [self.fetchedResultsController fetchedObjects];
    NSUInteger lastSeen = [posts indexOfObject:post];
    if (lastSeen == NSNotFound) return;
    for (NSUInteger i = 0; i < [posts count]; i++) {
        [posts[i] setBeenSeenValue:i <= lastSeen];
    }
    NSInteger readPosts = post.threadIndexValue - 1;
    if (self.thread.totalRepliesValue < readPosts) {
        // This can happen if new replies appear in between times we parse the total number of
        // replies in the thread.
        self.thread.totalRepliesValue = readPosts;
    }
    self.thread.totalUnreadPostsValue = self.thread.totalRepliesValue - readPosts;
    self.thread.seenValue = YES;
    [[AwfulDataStack sharedDataStack] save];
    self.markingPostsAsBeenSeen = NO;
}

- (void)goToParentForum
{
    NSString *url = [NSString stringWithFormat:@"awful://forums/%@", self.thread.forum.forumID];
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
}

- (void)scrollToBottom
{
    UIScrollView *scrollView = self.postsView.scrollView;
    [scrollView scrollRectToVisible:CGRectMake(0, scrollView.contentSize.height - 1, 1, 1)
                           animated:YES];
}

- (void)loadNextPageOrRefresh
{
    if (self.thread.numberOfPagesValue > self.currentPage) {
        [self loadPage:self.currentPage + 1];
    } else {
        [self loadPage:self.currentPage];
    }
}

- (void)updatePageBar
{
    [self.pageBar.backForwardControl setEnabled:self.currentPage > 1
                              forSegmentAtIndex:0];
    if (self.currentPage > 0 && self.currentPage < self.thread.numberOfPagesValue) {
        [self.pageBar.backForwardControl setEnabled:YES forSegmentAtIndex:1];
    } else {
        [self.pageBar.backForwardControl setEnabled:NO forSegmentAtIndex:1];
    }
    if (self.currentPage > 0 && self.thread.numberOfPagesValue > 0) {
        [self.pageBar.jumpToPageButton setTitle:[NSString stringWithFormat:@"Page %d of %@",
                                                 self.currentPage, self.thread.numberOfPages]
                                       forState:UIControlStateNormal];
    } else {
        [self.pageBar.jumpToPageButton setTitle:@"" forState:UIControlStateNormal];
    }
    [self.pageBar.actionsComposeControl setEnabled:self.thread.canReply forSegmentAtIndex:1];
}

- (void)updateTopBar
{
    self.topBar.scrollToBottomButton.enabled = [self.posts count] > 0;
    self.topBar.loadReadPostsButton.enabled = self.hiddenPosts > 0;
}

- (void)tappedPagesSegment:(id)sender
{
    UISegmentedControl *backForward = sender;
    if (backForward.selectedSegmentIndex == 0) {
        [self prevPage];
    } else if (backForward.selectedSegmentIndex == 1) {
        [self nextPage];
    }
    backForward.selectedSegmentIndex = UISegmentedControlNoSegment;
}

- (void)tappedActionsSegment:(id)sender
{
    UISegmentedControl *actions = sender;
    if (actions.selectedSegmentIndex == 0) {
        [self tappedActions];
    } else if (actions.selectedSegmentIndex == 1) {
        [self tappedCompose];
    }
    actions.selectedSegmentIndex = UISegmentedControlNoSegment;
}

- (void)nextPage
{
    if (self.currentPage >= self.thread.numberOfPagesValue) return;
    [self loadPage:self.currentPage + 1];
}

- (void)prevPage
{
    if (self.currentPage <= 1) return;
    [self loadPage:self.currentPage - 1];
}

- (void)tappedActions
{
    CGRect rect = self.pageBar.actionsComposeControl.frame;
    rect.size.width /= 2;
    rect = [self.view.superview convertRect:rect fromView:self.pageBar];
    [self showThreadActionsFromRect:rect inView:self.view.superview];
}

- (void)showThreadActionsFromRect:(CGRect)rect inView:(UIView *)view
{
    AwfulActionSheet *sheet = [AwfulActionSheet new];
    [sheet addButtonWithTitle:@"Copy Thread URL" block:^{
        NSString *url = [NSString stringWithFormat:@"http://forums.somethingawful.com/"
                         "showthread.php?threadid=%@&perpage=40&pagenumber=%@",
                         self.thread.threadID, @(self.currentPage)];
        [UIPasteboard generalPasteboard].URL = [NSURL URLWithString:url];
    }];
    [sheet addButtonWithTitle:@"Vote" block:^{
        AwfulActionSheet *vote = [AwfulActionSheet new];
        for (int i = 5; i >= 1; i--) {
            [vote addButtonWithTitle:[@(i) stringValue] block:^{
                [[AwfulHTTPClient client] rateThreadWithID:self.thread.threadID
                                                    rating:i
                                                   andThen:^(NSError *error)
                 {
                     NSLog(@"error casting vote on thread %@: %@", self.thread.threadID, error);
                 }];
            }];
        }
        [vote addCancelButtonWithTitle:@"Cancel"];
        [vote showFromRect:rect inView:view animated:YES];
    }];
    NSString *bookmark = self.thread.isBookmarkedValue ? @"Unbookmark Thread" : @"Bookmark Thread";
    [sheet addButtonWithTitle:bookmark block:^{
        [[AwfulHTTPClient client] setThreadWithID:self.thread.threadID
                                     isBookmarked:!self.thread.isBookmarkedValue
                                          andThen:^(NSError *error)
         {
             if (error) {
                 NSLog(@"error %@bookmarking thread %@: %@",
                       self.thread.isBookmarkedValue ? @"un" : @"", self.thread.threadID, error);
             } else {
                 self.thread.isBookmarkedValue = NO;
                 [[AwfulDataStack sharedDataStack] save];
             }
         }];
    }];
    [sheet addCancelButtonWithTitle:@"Cancel"];
    [sheet showFromRect:rect inView:view animated:YES];
}

- (void)tappedPageNav:(id)sender
{
    if (self.specificPageController) {
        [self dismissPopoverAnimated:YES];
        [self.specificPageController willMoveToParentViewController:nil];
        [self.specificPageController hideAnimated:YES];
        [self.specificPageController removeFromParentViewController];
        self.specificPageController = nil;
        return;
    }
    if (self.postsView.loadingMessage) return;
    if (self.thread.numberOfPagesValue < 1) return;
    self.specificPageController = [AwfulSpecificPageController new];
    self.specificPageController.delegate = self;
    [self.specificPageController reloadPages];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self.specificPageController reloadPages];
        self.popover = [[UIPopoverController alloc]
                        initWithContentViewController:self.specificPageController];
        self.popover.delegate = self;
        self.popover.popoverContentSize = self.specificPageController.view.bounds.size;
        [self.popover presentPopoverFromRect:self.pageBar.jumpToPageButton.frame
                                      inView:self.pageBar
                    permittedArrowDirections:UIPopoverArrowDirectionAny
                                    animated:YES];
    } else {
        [self addChildViewController:self.specificPageController];
        [self.specificPageController showInView:self.postsView animated:YES];
        [self.specificPageController didMoveToParentViewController:self];
    }
}

- (void)tappedCompose
{
    [self dismissPopoverAnimated:YES];
    AwfulReplyViewController *reply = [AwfulReplyViewController new];
    reply.delegate = self;
    [reply replyToThread:self.thread withInitialContents:nil];
    UINavigationController *nav = [reply enclosingNavigationController];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)showActionsForPost:(AwfulPost *)post fromRect:(CGRect)rect inView:(UIView *)view
{
    [self dismissPopoverAnimated:YES];
    NSString *title = [NSString stringWithFormat:@"%@'s Post", post.authorName];
    if ([post.authorName isEqualToString:[AwfulSettings settings].username]) {
        title = @"Your Post";
    }
    AwfulActionSheet *sheet = [[AwfulActionSheet alloc] initWithTitle:title];
    if (post.editableValue) {
        [sheet addButtonWithTitle:@"Edit" block:^{
            [[AwfulHTTPClient client] getTextOfPostWithID:post.postID
                                                  andThen:^(NSError *error, NSString *text)
             {
                 if (error) {
                     [AwfulAlertView showWithTitle:@"Could Not Edit Post"
                                             error:error
                                       buttonTitle:@"Alright"];
                     return;
                 }
                 AwfulReplyViewController *reply = [AwfulReplyViewController new];
                 reply.delegate = self;
                 [reply editPost:post text:text];
                 UINavigationController *nav = [reply enclosingNavigationController];
                 [self presentViewController:nav animated:YES completion:nil];
             }];
        }];
    }
    if (!self.thread.isLockedValue) {
        [sheet addButtonWithTitle:@"Quote" block:^{
            [[AwfulHTTPClient client] quoteTextOfPostWithID:post.postID
                                                    andThen:^(NSError *error, NSString *quotedText)
             {
                 if (error) {
                     [AwfulAlertView showWithTitle:@"Could Not Quote Post"
                                             error:error
                                       buttonTitle:@"Alright"];
                     return;
                 }
                 AwfulReplyViewController *reply = [AwfulReplyViewController new];
                 reply.delegate = self;
                 [reply replyToThread:self.thread
                  withInitialContents:[quotedText stringByAppendingString:@"\n\n"]];
                 UINavigationController *nav = [reply enclosingNavigationController];
                 [self presentViewController:nav animated:YES completion:nil];
             }];
        }];
    }
    [sheet addButtonWithTitle:@"Copy Post URL" block:^{
        NSString *url = [NSString stringWithFormat:@"http://forums.somethingawful.com/"
                         "showthread.php?threadid=%@&perpage=40&pagenumber=%@#post%@",
                         self.thread.threadID, @(self.currentPage), post.postID];
        [UIPasteboard generalPasteboard].URL = [NSURL URLWithString:url];
    }];
    [sheet addButtonWithTitle:@"Mark Read to Here" block:^{
        [[AwfulHTTPClient client] markThreadWithID:self.thread.threadID
                               readUpToPostAtIndex:[@(post.threadIndexValue) stringValue]
                                           andThen:^(NSError *error)
         {
             if (error) {
                 [AwfulAlertView showWithTitle:@"Could Not Mark Read"
                                         error:error
                                   buttonTitle:@"Alright"];
             } else {
                 [SVProgressHUD showSuccessWithStatus:@"Marked"];
                 self.didJustMarkAsReadToHere = YES;
                 [self markPostsAsBeenSeenUpToPost:post];
             }
         }];
    }];
    [sheet addCancelButtonWithTitle:@"Cancel"];
    [sheet showFromRect:rect inView:view animated:YES];
}

- (void)dismissPopoverAnimated:(BOOL)animated
{
    if (self.popover) {
        [self.popover dismissPopoverAnimated:animated];
        self.popover = nil;
        if (self.specificPageController) self.specificPageController = nil;
    }
}

- (void)updatePullUpTriggerOffset
{
    if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation)) {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            self.pullUpToRefreshControl.triggerOffset = 45;
        } else {
            self.pullUpToRefreshControl.triggerOffset = 35;
        }
    } else {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            self.pullUpToRefreshControl.triggerOffset = 25;
        } else {
            self.pullUpToRefreshControl.triggerOffset = 0;
        }
    }
}

- (void)showHiddenSeenPosts
{
    [self.postsView beginUpdates];
    for (NSInteger i = 0; i < self.hiddenPosts; i++) {
        [self.postsView insertPostAtIndex:i];
    }
    self.hiddenPosts = 0;
    [self.postsView endUpdates];
    [self maintainScrollOffsetAfterSizeChange];
}

- (void)retheme
{
    AwfulTheme *theme = [AwfulTheme currentTheme];
    self.view.backgroundColor = theme.postsViewBackgroundColor;
    self.topBar.backgroundColor = theme.postsViewTopBarMarginColor;
    NSArray *buttons = @[ self.topBar.goToForumButton, self.topBar.loadReadPostsButton,
                          self.topBar.scrollToBottomButton ];
    for (UIButton *button in buttons) {
        [button setTitleColor:theme.postsViewTopBarButtonTextColor forState:UIControlStateNormal];
        [button setTitleShadowColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [button setTitleColor:theme.postsViewTopBarButtonDisabledTextColor
                     forState:UIControlStateDisabled];
        button.backgroundColor = theme.postsViewTopBarButtonBackgroundColor;
    }
    self.pullUpToRefreshControl.spinnerStyle = theme.activityIndicatorViewStyle;
    self.pullUpToRefreshControl.textColor = theme.postsViewPullUpForNextPageTextAndArrowColor;
    self.pullUpToRefreshControl.arrowColor = theme.postsViewPullUpForNextPageTextAndArrowColor;
    self.postsView.dark = [AwfulSettings settings].darkTheme;
}

- (void)configurePostsViewSettings
{
    self.postsView.showAvatars = [AwfulSettings settings].showAvatars;
    self.postsView.showImages = [AwfulSettings settings].showImages;
    if ([AwfulSettings settings].highlightOwnMentions) {
        self.postsView.highlightMentionUsername = [AwfulSettings settings].username;
    } else {
        self.postsView.highlightMentionUsername = nil;
    }
    if ([AwfulSettings settings].highlightOwnQuotes) {
        self.postsView.highlightQuoteUsername = [AwfulSettings settings].username;
    } else {
        self.postsView.highlightQuoteUsername = nil;
    }
    self.postsView.stylesheetURL = StylesheetURLForForumWithID(self.thread.forum.forumID);
}

#pragma mark - UIViewController

- (void)setTitle:(NSString *)title
{
    [super setTitle:title];
    self.navigationItem.titleLabel.text = title;
    [self.navigationItem.titleView setNeedsLayout];
}

- (void)loadView
{
    self.view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    CGRect postsFrame, pageBarFrame;
    CGRectDivide(self.view.bounds, &pageBarFrame, &postsFrame, 38, CGRectMaxYEdge);
    
    AwfulPageBar *pageBar = [[AwfulPageBar alloc] initWithFrame:pageBarFrame];
    [pageBar.backForwardControl addTarget:self
                                   action:@selector(tappedPagesSegment:)
                         forControlEvents:UIControlEventValueChanged];
    [pageBar.jumpToPageButton addTarget:self
                                 action:@selector(tappedPageNav:)
                       forControlEvents:UIControlEventTouchUpInside];
    [pageBar.actionsComposeControl addTarget:self
                                      action:@selector(tappedActionsSegment:)
                            forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:pageBar];
    self.pageBar = pageBar;
    [self updatePageBar];
    
    AwfulPostsView *postsView = [[AwfulPostsView alloc] initWithFrame:postsFrame];
    postsView.delegate = self;
    postsView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    postsView.backgroundColor = self.view.backgroundColor;
    self.postsView = postsView;
    [self.view addSubview:postsView];
    [self configurePostsViewSettings];
    
    TopBarView *topBar = [TopBarView new];
    topBar.frame = CGRectMake(0, -40, self.view.frame.size.width, 40);
    topBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [topBar.goToForumButton addTarget:self
                               action:@selector(goToParentForum)
                     forControlEvents:UIControlEventTouchUpInside];
    [topBar.loadReadPostsButton addTarget:self
                                   action:@selector(showHiddenSeenPosts)
                         forControlEvents:UIControlEventTouchUpInside];
    topBar.loadReadPostsButton.enabled = self.hiddenPosts > 0;
    [topBar.scrollToBottomButton addTarget:self
                                    action:@selector(scrollToBottom)
                          forControlEvents:UIControlEventTouchUpInside];
    [postsView.scrollView addSubview:topBar];
    self.topBar = topBar;
    postsView.scrollView.contentInset = UIEdgeInsetsMake(topBar.bounds.size.height, 0, 0, 0);
    postsView.scrollView.scrollIndicatorInsets = postsView.scrollView.contentInset;
    postsView.scrollView.delegate = self;
    
    AwfulPullToRefreshControl *refresh;
    refresh = [[AwfulPullToRefreshControl alloc] initWithDirection:AwfulScrollViewPullUp];
    [refresh addTarget:self
                action:@selector(loadNextPageOrRefresh)
      forControlEvents:UIControlEventValueChanged];
    refresh.backgroundColor = postsView.backgroundColor;
    [self.postsView.scrollView addSubview:refresh];
    self.pullUpToRefreshControl = refresh;
    [self updatePullUpTriggerOffset];
    
    [self.view bringSubviewToFront:self.pageBar];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self retheme];
}

- (void)viewDidDisappear:(BOOL)animated
{    
    // Blank the web view if we're leaving for good. Otherwise we get weirdness like videos
    // continuing to play their sound after the user switches to a different thread.
    if (!self.navigationController) {
        [self.postsView clearAllPosts];
        [self markPostsAsBeenSeen];
    }
    [super viewDidDisappear:animated];
}

- (void)maintainScrollOffsetAfterSizeChange
{
    _observingScrollViewSize = YES;
    [self.postsView.scrollView addObserver:self
                                forKeyPath:@"contentSize"
                                   options:(NSKeyValueObservingOptionOld |
                                            NSKeyValueObservingOptionNew)
                                   context:&KVOContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (context != &KVOContext) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }
    if ([keyPath isEqualToString:@"contentSize"]) {
        CGSize oldSize = [change[NSKeyValueChangeOldKey] CGSizeValue];
        CGSize newSize = [change[NSKeyValueChangeNewKey] CGSizeValue];
        CGPoint contentOffset = [object contentOffset];
        contentOffset.y += newSize.height - oldSize.height;
        [object setContentOffset:contentOffset];
        [object removeObserver:self forKeyPath:keyPath context:context];
        _observingScrollViewSize = NO;
    }
}

static char KVOContext;

- (void)stopObserving
{
    if (_observingScrollViewSize) {
        [self.postsView.scrollView removeObserver:self
                                       forKeyPath:@"contentSize"
                                          context:&KVOContext];
    }
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                         duration:(NSTimeInterval)duration
{
    [self updatePullUpTriggerOffset];
    if (self.specificPageController && !self.popover) {
        CGRect frame = self.specificPageController.view.frame;
        frame.size.width = self.view.frame.size.width;
        frame.origin.y = self.postsView.frame.size.height - frame.size.height;
        self.specificPageController.view.frame = frame;
    }
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [self.popover presentPopoverFromRect:self.pageBar.jumpToPageButton.frame
                                  inView:self.pageBar
                permittedArrowDirections:UIPopoverArrowDirectionAny
                                animated:NO];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return YES;
    }
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

#pragma mark - AwfulPostsViewDelegate

- (NSInteger)numberOfPostsInPostsView:(AwfulPostsView *)postsView
{
    return [[self.fetchedResultsController fetchedObjects] count] - self.hiddenPosts;
}

- (NSDictionary *)postsView:(AwfulPostsView *)postsView postAtIndex:(NSInteger)index
{
    AwfulPost *post = self.fetchedResultsController.fetchedObjects[index + self.hiddenPosts];
    NSArray *keys = @[
        @"postID", @"authorName", @"authorAvatarURL", @"beenSeen", @"innerHTML",
        @"authorIsOriginalPoster", @"authorIsAModerator", @"authorIsAnAdministrator"
    ];
    NSMutableDictionary *dict = [[post dictionaryWithValuesForKeys:keys] mutableCopy];
    if (post.postDate) {
        dict[@"postDate"] = [self.postDateFormatter stringFromDate:post.postDate];
    }
    if (post.authorRegDate) {
        dict[@"authorRegDate"] = [self.regDateFormatter stringFromDate:post.authorRegDate];
    }
    return dict;
}

- (NSString *)advertisementHTMLForPostsView:(AwfulPostsView *)postsView
{
    return self.advertisementHTML;
}

- (void)postsView:(AwfulPostsView *)postsView didTapLinkToURL:(NSURL *)url
{
    // Anything not on the Forums goes to Safari (or wherever).
    if ([[url host] compare:@"forums.somethingawful.com" options:NSCaseInsensitiveSearch] !=
        NSOrderedSame) {
        [[UIApplication sharedApplication] openURL:url];
        return;
    }
    
    NSDictionary *query = [url queryDictionary];
    NSString *redirect;
    // Thread or post.
    if ([[url path] compare:@"/showthread.php" options:NSCaseInsensitiveSearch] == NSOrderedSame) {
        // Link to specific post.
        if ([query[@"goto"] isEqual:@"post"] && query[@"postid"]) {
            redirect = [NSString stringWithFormat:@"awful://posts/%@", query[@"postid"]];
        }
        // Link to specific post.
        else if ([[url fragment] hasPrefix:@"post"] && [[url fragment] length] > 4) {
            redirect = [NSString stringWithFormat:@"awful://posts/%@",
                        [[url fragment] substringFromIndex:4]];
        }
        // Link to page on specific thread.
        else if (query[@"threadid"] && query[@"pagenumber"]) {
            redirect = [NSString stringWithFormat:@"awful://threads/%@/pages/%@",
                        query[@"threadid"], query[@"pagenumber"]];
        }
        // Link to specific thread.
        else if (query[@"threadid"]) {
            redirect = [NSString stringWithFormat:@"awful://threads/%@/pages/1",
                        query[@"threadid"]];
        }
    }
    // Forum.
    else if ([[url path] compare:@"/forumdisplay.php" options:NSCaseInsensitiveSearch] ==
             NSOrderedSame) {
        if (query[@"forumid"]) {
            redirect = [NSString stringWithFormat:@"awful://forums/%@", query[@"forumid"]];
        }
    }
    if (redirect) url = [NSURL URLWithString:redirect];
    [[UIApplication sharedApplication] openURL:url];
}

- (NSArray *)whitelistedSelectorsForPostsView:(AwfulPostsView *)postsView
{
    return @[ @"showActionsForPostAtIndex:fromRectDictionary:", @"previewImageAtURLString:" ];
}

- (void)showActionsForPostAtIndex:(NSNumber *)index fromRectDictionary:(NSDictionary *)rectDict
{
    NSInteger unboxed = [index integerValue] + self.hiddenPosts;
    AwfulPost *post = self.fetchedResultsController.fetchedObjects[unboxed];
    CGRect rect = CGRectMake([rectDict[@"left"] floatValue], [rectDict[@"top"] floatValue],
                             [rectDict[@"width"] floatValue], [rectDict[@"height"] floatValue]);
    if (self.postsView.scrollView.contentOffset.y < 0) {
        rect.origin.y -= self.postsView.scrollView.contentOffset.y;
    }
    [self showActionsForPost:post fromRect:rect inView:self.postsView];
}

- (void)previewImageAtURLString:(NSString *)urlString
{
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        NSLog(@"could not parse URL for image preview: %@", urlString);
        return;
    }
    AwfulImagePreviewViewController *preview = [[AwfulImagePreviewViewController alloc]
                                                initWithURL:url];
    preview.title = self.title;
    UINavigationController *nav = [preview enclosingNavigationController];
    nav.navigationBar.translucent = YES;
    [self presentViewController:nav animated:YES completion:nil];
}

- (NSDateFormatter *)regDateFormatter
{
    if (_regDateFormatter) return _regDateFormatter;
    _regDateFormatter = [NSDateFormatter new];
    // Jan 2, 2003
    _regDateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
    _regDateFormatter.dateFormat = @"MMM d, yyyy";
    return _regDateFormatter;
}

- (NSDateFormatter *)postDateFormatter
{
    if (_postDateFormatter) return _postDateFormatter;
    _postDateFormatter = [NSDateFormatter new];
    // Jan 2, 2003 16:05
    _postDateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
    _postDateFormatter.dateFormat = @"MMM d, yyyy HH:mm";
    return _postDateFormatter;
}

#pragma mark - NSFetchedResultsControllerDelegate

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    if (!self.cachedUpdatesWhileScrolling) [self.postsView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller
   didChangeObject:(AwfulPost *)post
       atIndexPath:(NSIndexPath *)indexPath
     forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    if (self.markingPostsAsBeenSeen) return;
    if (self.cachedUpdatesWhileScrolling) {
        NSMethodSignature *signature = [self methodSignatureForSelector:_cmd];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
        invocation.selector = _cmd;
        [invocation setArgument:&controller atIndex:2];
        [invocation setArgument:&post atIndex:3];
        [invocation setArgument:&indexPath atIndex:4];
        [invocation setArgument:&type atIndex:5];
        [invocation setArgument:&newIndexPath atIndex:6];
        [invocation retainArguments];
        [self.cachedUpdatesWhileScrolling addObject:invocation];
        return;
    }
    if (type == NSFetchedResultsChangeInsert) {
        if (newIndexPath.row < self.hiddenPosts) return;
        [self.postsView insertPostAtIndex:newIndexPath.row - self.hiddenPosts];
    } else if (type == NSFetchedResultsChangeDelete) {
        if (indexPath.row < self.hiddenPosts) return;
        [self.postsView deletePostAtIndex:indexPath.row - self.hiddenPosts];
    } else if (type == NSFetchedResultsChangeUpdate) {
        if (indexPath.row < self.hiddenPosts) return;
        [self.postsView reloadPostAtIndex:indexPath.row - self.hiddenPosts];
    } else if (type == NSFetchedResultsChangeMove) {
        if (indexPath.row >= self.hiddenPosts) {
            [self.postsView deletePostAtIndex:indexPath.row - self.hiddenPosts];
        }
        if (newIndexPath.row >= self.hiddenPosts) {
            [self.postsView insertPostAtIndex:newIndexPath.row - self.hiddenPosts];
        }
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    if (!self.cachedUpdatesWhileScrolling) [self.postsView endUpdates];
    [self.pullUpToRefreshControl setRefreshing:NO animated:YES];
    [self updatePullForNextPageLabel];
}

#pragma mark - AwfulSpecificPageControllerDelegate

- (NSInteger)numberOfPagesInSpecificPageController:(AwfulSpecificPageController *)controller
{
    return self.thread.numberOfPagesValue;
}

- (NSInteger)currentPageForSpecificPageController:(AwfulSpecificPageController *)controller
{
    if (self.currentPage > 0) {
        return self.currentPage;
    }
    else if (self.currentPage == AwfulPageLast && self.thread.numberOfPagesValue > 0) {
        return self.thread.numberOfPagesValue;
    } else {
        return 1;
    }
}

- (void)specificPageController:(AwfulSpecificPageController *)controller
                 didSelectPage:(NSInteger)page
{
    if (self.popover) {
        [self dismissPopoverAnimated:YES];
    } else {
        [self.specificPageController hideAnimated:YES];
        self.specificPageController = nil;
    }
    [self loadPage:page];
}

- (void)specificPageControllerDidCancel:(AwfulSpecificPageController *)controller
{
    [self dismissPopoverAnimated:YES];
    self.specificPageController = nil;
}

#pragma mark - UIPopoverControllerDelegate

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popover
{
    if (popover == self.popover) {
        self.popover = nil;
        self.specificPageController = nil;
    }
}

#pragma mark - AwfulReplyViewControllerDelegate

- (void)replyViewController:(AwfulReplyViewController *)replyViewController
           didReplyToThread:(AwfulThread *)thread
{
    [self dismissViewControllerAnimated:YES completion:^{
        [self loadPage:AwfulPageNextUnread];
    }];
}

- (void)replyViewController:(AwfulReplyViewController *)replyViewController
                didEditPost:(AwfulPost *)post
{
    [self dismissViewControllerAnimated:YES completion:^{
        [self loadPage:post.threadPageValue];
        [self jumpToPostWithID:post.postID];
    }];
}

- (void)replyViewControllerDidCancel:(AwfulReplyViewController *)replyViewController
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    if (!self.cachedUpdatesWhileScrolling) self.cachedUpdatesWhileScrolling = [NSMutableArray new];
    
    self.lastContentOffset = scrollView.contentOffset;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    CGRect topBarFrame = self.topBar.frame;
    // Stick top bar underneath navigation bar; it shouldn't bounce.
    if (scrollView.contentOffset.y <= -topBarFrame.size.height) {
        topBarFrame.origin.y = scrollView.contentOffset.y;
    } else {
        // When we scroll down, the top bar stays perched atop the scroll view. Though we let it
        // scroll out of view if needed
        if (!self.scrollingUp) {
            if (!CGRectIntersectsRect(topBarFrame, scrollView.bounds)) {
                topBarFrame.origin.y = -topBarFrame.size.height;
            }
        }
        // Anytime we scroll up, keep the top bar visible if it was already.
        else if (topBarFrame.origin.y > scrollView.contentOffset.y) {
            topBarFrame.origin.y = CGRectGetMinY(scrollView.bounds);
        }
    }
    self.topBar.frame = topBarFrame;
    if (!CGPointEqualToPoint(self.lastContentOffset, scrollView.contentOffset)) {
        self.scrollingUp = scrollView.contentOffset.y < self.lastContentOffset.y;
        self.lastContentOffset = scrollView.contentOffset;
    }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)willDecelerate
{
    if (!willDecelerate) [self processCachedUpdates];
    
    // If we're decelerating upwards and the top bar isn't already visible, put the top bar just
    // out of view so it slides in.
    CGRect topBarFrame = self.topBar.frame;
    if (willDecelerate && self.scrollingUp && topBarFrame.origin.y >= -topBarFrame.size.height &&
        topBarFrame.origin.y < CGRectGetMinY(scrollView.bounds) - topBarFrame.size.height) {
        topBarFrame.origin.y = CGRectGetMinY(scrollView.bounds) - topBarFrame.size.height;
        if (topBarFrame.origin.y < -topBarFrame.size.height) {
            topBarFrame.origin.y = -topBarFrame.size.height;
        }
        self.topBar.frame = topBarFrame;
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    [self processCachedUpdates];
}

- (void)processCachedUpdates
{
    NSArray *invocations = [self.cachedUpdatesWhileScrolling copy];
    self.cachedUpdatesWhileScrolling = nil;
    [self.postsView beginUpdates];
    [invocations makeObjectsPerformSelector:@selector(invokeWithTarget:) withObject:self];
    [self.postsView endUpdates];
}

@end


@interface TopBarView ()

@property (weak, nonatomic) UIButton *goToForumButton;

@property (weak, nonatomic) UIButton *loadReadPostsButton;

@property (weak, nonatomic) UIButton *scrollToBottomButton;

@end


@implementation TopBarView

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    UIButton *goToForumButton = [self makeButton];
    [goToForumButton setTitle:@"Parent Forum" forState:UIControlStateNormal];
    goToForumButton.accessibilityLabel = @"Parent forum";
    goToForumButton.accessibilityHint = @"Opens this thread's forum";
    _goToForumButton = goToForumButton;
    
    UIButton *loadReadPostsButton = [self makeButton];
    [loadReadPostsButton setTitle:@"Previous Posts" forState:UIControlStateNormal];
    loadReadPostsButton.accessibilityLabel = @"Previous posts";
    _loadReadPostsButton = loadReadPostsButton;
    
    UIButton *scrollToBottomButton = [self makeButton];
    [scrollToBottomButton setTitle:@"Scroll To End" forState:UIControlStateNormal];
    scrollToBottomButton.accessibilityLabel = @"Scroll to end";
    _scrollToBottomButton = scrollToBottomButton;
    
    return self;
}

- (UIButton *)makeButton
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [self addSubview:button];
    return button;
}

- (void)layoutSubviews
{
    CGFloat buttonWidth = floorf((self.bounds.size.width - 2) / 3);
    CGFloat x = floorf(self.bounds.size.width - buttonWidth * 3) / 2;
    
    self.goToForumButton.frame = CGRectMake(x, 0, buttonWidth, self.bounds.size.height - 1);
    x += buttonWidth + 1;
    self.loadReadPostsButton.frame = CGRectMake(x, 0, buttonWidth, self.bounds.size.height - 1);
    x += buttonWidth + 1;
    self.scrollToBottomButton.frame = CGRectMake(x, 0, buttonWidth, self.bounds.size.height - 1);
}

@end
