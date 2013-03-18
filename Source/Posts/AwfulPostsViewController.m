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
#import "AwfulBrowserViewController.h"
#import "AwfulDataStack.h"
#import "AwfulDateFormatters.h"
#import "AwfulExternalBrowser.h"
#import "AwfulHTTPClient.h"
#import "AwfulImagePreviewViewController.h"
#import "AwfulJumpToPageSheet.h"
#import "AwfulModels.h"
#import "AwfulPageBottomBar.h"
#import "AwfulPageTopBar.h"
#import "AwfulPostsView.h"
#import "AwfulProfileViewController.h"
#import "AwfulPullToRefreshControl.h"
#import "AwfulReplyComposeViewController.h"
#import "AwfulSettings.h"
#import "AwfulTheme.h"
#import "AwfulThemingViewController.h"
#import "NSFileManager+UserDirectories.h"
#import "NSManagedObject+Awful.h"
#import "NSString+CollapseWhitespace.h"
#import "NSURL+Awful.h"
#import "NSURL+OpensInBrowser.h"
#import "NSURL+Punycode.h"
#import "NSURL+QueryDictionary.h"
#import "SVProgressHUD.h"
#import "UINavigationItem+TwoLineTitle.h"
#import "UIViewController+NavigationEnclosure.h"

@interface AwfulPostsViewController () <AwfulPostsViewDelegate,
                                        AwfulJumpToPageSheetDelegate,
                                        NSFetchedResultsControllerDelegate,
                                        AwfulReplyComposeViewControllerDelegate,
                                        UIScrollViewDelegate,
                                        AwfulThemingViewController>

@property (nonatomic) AwfulThreadPage currentPage;

@property (nonatomic) NSFetchedResultsController *fetchedResultsController;

@property (weak, nonatomic) NSOperation *networkOperation;

@property (weak, nonatomic) AwfulPageTopBar *topBar;
@property (weak, nonatomic) AwfulPostsView *postsView;
@property (weak, nonatomic) AwfulPageBottomBar *bottomBar;
@property (weak, nonatomic) AwfulPullToRefreshControl *pullUpToRefreshControl;

@property (nonatomic) AwfulJumpToPageSheet *jumpToPageSheet;

@property (nonatomic) NSInteger hiddenPosts;
@property (copy, nonatomic) NSString *jumpToPostAfterLoad;
@property (copy, nonatomic) NSString *advertisementHTML;

@property (nonatomic) NSDateFormatter *editDateFormatter;

@property (nonatomic) BOOL observingScrollViewSize;
@property (nonatomic) BOOL observingThreadSeenPosts;

@property (nonatomic) NSMutableArray *cachedUpdatesWhileScrolling;

@end


@implementation AwfulPostsViewController

- (id)init
{
    if (!(self = [super initWithNibName:nil bundle:nil])) return nil;
    self.hidesBottomBarWhenPushed = YES;
    NSNotificationCenter *noteCenter = [NSNotificationCenter defaultCenter];
    [noteCenter addObserver:self selector:@selector(settingChanged:)
                       name:AwfulSettingsDidChangeNotification object:nil];
    [noteCenter addObserver:self selector:@selector(didResetDataStack:)
                       name:AwfulDataStackDidResetNotification object:nil];
    return self;
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
        AwfulSettingsKeys.yosposStyle,
        AwfulSettingsKeys.fontScale,
    ];
    NSArray *keys = note.userInfo[AwfulSettingsDidChangeSettingsKey];
    if ([keys firstObjectCommonWithArray:importantKeys]) [self configurePostsViewSettings];
}

- (void)didResetDataStack:(NSNotification *)note
{
    self.fetchedResultsController = nil;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopObservingScrollViewContentSize];
    self.postsView.scrollView.delegate = nil;
    self.fetchedResultsController.delegate = nil;
    [self stopObservingThreadSeenPosts];
}

- (void)setThread:(AwfulThread *)thread
{
    if ([_thread isEqual:thread]) return;
    [self willChangeValueForKey:@"thread"];
    _thread = thread;
    [self didChangeValueForKey:@"thread"];
    [self updateFetchedResultsController];
    [self updateUserInterface];
    self.postsView.stylesheetURL = StylesheetURLForForumWithIDAndSettings(self.thread.forum.forumID,
                                                                          [AwfulSettings settings]);
}

- (NSArray *)posts
{
    return self.fetchedResultsController.fetchedObjects;
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
    NSInteger lowIndex = (self.currentPage - 1) * 40 + 1;
    NSInteger highIndex = self.currentPage * 40;
    request.predicate = [NSPredicate predicateWithFormat:@"thread == %@ AND %d <= threadIndex AND threadIndex <= %d",
                         self.thread, lowIndex, highIndex];
    NSError *error;
    BOOL ok = [self.fetchedResultsController performFetch:&error];
    if (!ok) {
        NSLog(@"error fetching posts: %@", error);
    }
}

- (void)updateUserInterface
{
    self.title = [self.thread.title stringByCollapsingWhitespace];
    
    if (self.currentPage == AwfulThreadPageLast) {
        self.postsView.loadingMessage = @"Loading last page";
    } else if (self.currentPage == AwfulThreadPageNextUnread) {
        self.postsView.loadingMessage = @"Loading unread posts";
    } else if ([self.fetchedResultsController.fetchedObjects count] == 0) {
        self.postsView.loadingMessage = [NSString stringWithFormat:
                                         @"Loading page %d", self.currentPage];
    } else {
        self.postsView.loadingMessage = nil;
    }
    
    self.topBar.scrollToBottomButton.enabled = [self.posts count] > 0;
    self.topBar.loadReadPostsButton.enabled = self.hiddenPosts > 0;
    
    if (self.currentPage > 0 && self.currentPage >= self.thread.numberOfPagesValue) {
        self.postsView.endMessage = @"End of the thread";
    } else {
        self.postsView.endMessage = nil;
    }
    
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
    
    [self.bottomBar.backForwardControl setEnabled:self.currentPage > 1
                                forSegmentAtIndex:0];
    if (self.currentPage > 0 && self.currentPage < self.thread.numberOfPagesValue) {
        [self.bottomBar.backForwardControl setEnabled:YES forSegmentAtIndex:1];
    } else {
        [self.bottomBar.backForwardControl setEnabled:NO forSegmentAtIndex:1];
    }
    if (self.currentPage > 0 && self.thread.numberOfPagesValue > 0) {
        [self.bottomBar.jumpToPageButton setTitle:[NSString stringWithFormat:@"Page %d of %@",
                                                   self.currentPage, self.thread.numberOfPages]
                                         forState:UIControlStateNormal];
    } else {
        [self.bottomBar.jumpToPageButton setTitle:@"" forState:UIControlStateNormal];
    }
    [self.bottomBar.actionsComposeControl setEnabled:!self.thread.isClosedValue
                                   forSegmentAtIndex:1];
}

- (void)configurePostsViewSettings
{
    self.postsView.showAvatars = [AwfulSettings settings].showAvatars;
    self.postsView.showImages = [AwfulSettings settings].showImages;
    self.postsView.fontScale = [AwfulSettings settings].fontScale;
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
    self.postsView.stylesheetURL = StylesheetURLForForumWithIDAndSettings(self.thread.forum.forumID,
                                                                          [AwfulSettings settings]);
}

- (AwfulPostsView *)postsView
{
    if (!_postsView) [self view];
    return _postsView;
}

- (void)setHiddenPosts:(NSInteger)hiddenPosts
{
    if (_hiddenPosts == hiddenPosts) return;
    _hiddenPosts = hiddenPosts;
    [self updateUserInterface];
}

- (void)loadPage:(AwfulThreadPage)page
{
    [self stopObservingThreadSeenPosts];
    [self.networkOperation cancel];
    self.jumpToPostAfterLoad = nil;
    NSInteger oldPage = self.currentPage;
    self.currentPage = page;
    BOOL refreshingSamePage = page > 0 && page == oldPage;
    if (!refreshingSamePage) {
        [self updateFetchedResultsController];
        self.pullUpToRefreshControl.refreshing = NO;
        [self updateUserInterface];
        UIEdgeInsets inset = self.postsView.scrollView.contentInset;
        [self.postsView.scrollView setContentOffset:CGPointMake(0, -inset.top) animated:NO];
        self.advertisementHTML = nil;
        self.hiddenPosts = 0;
        [self.postsView reloadData];
    }
    id op = [[AwfulHTTPClient client] listPostsInThreadWithID:self.thread.threadID
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
                if (![[self.bottomBar.jumpToPageButton titleForState:UIControlStateNormal] length]) {
                    if (self.thread.numberOfPagesValue > 0) {
                        NSString *title = [NSString stringWithFormat:@"Page ? of %@",
                                           self.thread.numberOfPages];
                        [self.bottomBar.jumpToPageButton setTitle:title
                                                       forState:UIControlStateNormal];
                    } else {
                        [self.bottomBar.jumpToPageButton setTitle:@"Page ? of ?"
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
        AwfulPost *lastPost = [posts lastObject];
        if (lastPost) {
            self.thread = [lastPost thread];
            self.currentPage = [lastPost page];
        }
        self.advertisementHTML = advertisementHTML;
        if (page == AwfulThreadPageNextUnread && firstUnreadPost != NSNotFound) {
            self.hiddenPosts = firstUnreadPost;
        }
        if (!self.fetchedResultsController) [self updateFetchedResultsController];
        if (wasLoading) {
            [self.postsView reloadData];
        } else {
            [self.postsView reloadAdvertisementHTML];
        }
        [self updateUserInterface];
        if (self.jumpToPostAfterLoad) {
            [self jumpToPostWithID:self.jumpToPostAfterLoad];
            self.jumpToPostAfterLoad = nil;
        } else if (wasLoading) {
            CGFloat inset = self.postsView.scrollView.contentInset.top;
            [self.postsView.scrollView setContentOffset:CGPointMake(0, -inset) animated:NO];
        }
        if (self.thread.seenPostsValue < lastPost.threadIndexValue) {
            self.thread.seenPostsValue = lastPost.threadIndexValue;
        }
        [self startObservingThreadSeenPosts];
    }];
    self.networkOperation = op;
}

- (void)startObservingThreadSeenPosts
{
    if (self.observingThreadSeenPosts) return;
    [self addObserver:self forKeyPath:@"thread.seenPosts" options:0 context:&KVOContext];
    self.observingThreadSeenPosts = YES;
}

- (void)stopObservingThreadSeenPosts
{
    if (!self.observingThreadSeenPosts) return;
    [self removeObserver:self forKeyPath:@"thread.seenPosts" context:&KVOContext];
    self.observingThreadSeenPosts = NO;
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

- (void)loadNextPageOrRefresh
{
    if (self.thread.numberOfPagesValue > self.currentPage) {
        [self loadPage:self.currentPage + 1];
    } else {
        [self loadPage:self.currentPage];
    }
}

- (void)showThreadActionsFromRect:(CGRect)rect inView:(UIView *)view
{
    AwfulActionSheet *sheet = [AwfulActionSheet new];
    [sheet addButtonWithTitle:@"Copy Thread URL" block:^{
        NSString *url = [NSString stringWithFormat:@"http://forums.somethingawful.com/"
                         "showthread.php?threadid=%@&perpage=40&pagenumber=%@",
                         self.thread.threadID, @(self.currentPage)];
        [UIPasteboard generalPasteboard].items = @[ @{
            (id)kUTTypeURL: [NSURL URLWithString:url],
            (id)kUTTypePlainText: url
        }];
    }];
    [sheet addButtonWithTitle:@"Vote" block:^{
        AwfulActionSheet *vote = [AwfulActionSheet new];
        for (int i = 5; i >= 1; i--) {
            [vote addButtonWithTitle:[@(i) stringValue] block:^{
                [[AwfulHTTPClient client] rateThreadWithID:self.thread.threadID
                                                    rating:i
                                                   andThen:^(NSError *error)
                 {
                     if (error) {
                         [AwfulAlertView showWithTitle:@"Vote Failed" error:error buttonTitle:@"OK"];
                     } else {
                         NSString *status = [NSString stringWithFormat:@"Voted %d", i];
                         [SVProgressHUD showSuccessWithStatus:status];
                     }
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
                 NSString *status = self.thread.isBookmarkedValue ? @"Bookmarked" : @"Unbookmarked";
                 [SVProgressHUD showSuccessWithStatus:status];
             }
         }];
    }];
    [sheet addCancelButtonWithTitle:@"Cancel"];
    [sheet showFromRect:rect inView:view animated:YES];
}

- (void)showProfileWithUser:(AwfulUser *)user
{
    AwfulProfileViewController *profile = [AwfulProfileViewController new];
    profile.userID = user.userID;
    UIBarButtonItem *item;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        item = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                             target:self
                                                             action:@selector(doneWithProfile)];
        profile.navigationItem.leftBarButtonItem = item;
        UINavigationController *nav = [profile enclosingNavigationController];
        nav.modalPresentationStyle = UIModalPresentationFormSheet;
        [self presentViewController:nav animated:YES completion:nil];
    } else {
        profile.hidesBottomBarWhenPushed = YES;
        item = [[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStyleBordered
                                               target:nil action:NULL];
        self.navigationItem.backBarButtonItem = item;
        [self.navigationController pushViewController:profile animated:YES];
    }
}

- (void)doneWithProfile
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - AwfulThemingViewController

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
    
    AwfulPageBottomBar *pageBar = [[AwfulPageBottomBar alloc] initWithFrame:pageBarFrame];
    [pageBar.backForwardControl addTarget:self
                                   action:@selector(didTapPreviousNextPageControl:)
                         forControlEvents:UIControlEventValueChanged];
    [pageBar.jumpToPageButton addTarget:self
                                 action:@selector(toggleJumpToPageSheet)
                       forControlEvents:UIControlEventTouchUpInside];
    [pageBar.actionsComposeControl addTarget:self
                                      action:@selector(didTapActComposeControl:)
                            forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:pageBar];
    self.bottomBar = pageBar;
    
    AwfulPostsView *postsView = [[AwfulPostsView alloc] initWithFrame:postsFrame];
    postsView.delegate = self;
    postsView.scrollView.delegate = self;
    postsView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    postsView.backgroundColor = self.view.backgroundColor;
    self.postsView = postsView;
    [self.view addSubview:postsView];
    [self configurePostsViewSettings];
    
    AwfulPageTopBar *topBar = [AwfulPageTopBar new];
    topBar.frame = CGRectMake(0, -40, CGRectGetWidth(self.view.frame), 40);
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
    
    AwfulPullToRefreshControl *refresh;
    refresh = [[AwfulPullToRefreshControl alloc] initWithDirection:AwfulScrollViewPullUp];
    [refresh addTarget:self
                action:@selector(loadNextPageOrRefresh)
      forControlEvents:UIControlEventValueChanged];
    refresh.backgroundColor = postsView.backgroundColor;
    [self.postsView.scrollView addSubview:refresh];
    self.pullUpToRefreshControl = refresh;
    [self updatePullUpTriggerOffset];
    
    [self updateUserInterface];
    
    [self.view bringSubviewToFront:self.bottomBar];
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

- (void)didTapPreviousNextPageControl:(UISegmentedControl *)seg
{
    if (seg.selectedSegmentIndex == 0) {
        if (self.currentPage > 1) {
            [self loadPage:self.currentPage - 1];
        }
    } else if (seg.selectedSegmentIndex == 1) {
        if (self.currentPage < self.thread.numberOfPagesValue) {
            [self loadPage:self.currentPage + 1];
        }
    }
    seg.selectedSegmentIndex = UISegmentedControlNoSegment;
}

- (void)toggleJumpToPageSheet
{
    if (self.jumpToPageSheet) {
        [self.jumpToPageSheet dismiss];
        self.jumpToPageSheet = nil;
        return;
    }
    if (self.postsView.loadingMessage) return;
    if (self.thread.numberOfPagesValue < 1) return;
    self.jumpToPageSheet = [[AwfulJumpToPageSheet alloc] initWithDelegate:self];
    [self.jumpToPageSheet showInView:self.view behindSubview:self.bottomBar];
}

- (void)didTapActComposeControl:(UISegmentedControl *)seg
{
    if (seg.selectedSegmentIndex == 0) {
        CGRect rect = self.bottomBar.actionsComposeControl.frame;
        rect.size.width /= 2;
        rect = [self.view.superview convertRect:rect fromView:self.bottomBar];
        [self showThreadActionsFromRect:rect inView:self.view.superview];
    } else if (seg.selectedSegmentIndex == 1) {
        AwfulReplyComposeViewController *reply = [AwfulReplyComposeViewController new];
        reply.delegate = self;
        [reply replyToThread:self.thread withInitialContents:nil];
        UINavigationController *nav = [reply enclosingNavigationController];
        [self presentViewController:nav animated:YES completion:nil];
    }
    seg.selectedSegmentIndex = UISegmentedControlNoSegment;
}

- (void)goToParentForum
{
    NSString *url = [NSString stringWithFormat:@"awful://forums/%@", self.thread.forum.forumID];
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
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

- (void)maintainScrollOffsetAfterSizeChange
{
    _observingScrollViewSize = YES;
    [self.postsView.scrollView addObserver:self
                                forKeyPath:@"contentSize"
                                   options:(NSKeyValueObservingOptionOld |
                                            NSKeyValueObservingOptionNew)
                                   context:&KVOContext];
}

- (void)scrollToBottom
{
    UIScrollView *scrollView = self.postsView.scrollView;
    [scrollView scrollRectToVisible:CGRectMake(0, scrollView.contentSize.height - 1, 1, 1)
                           animated:YES];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self retheme];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    // When the built-in browser or a user profile gets pushed, we change the back button. This
    // resets it to the default.
    self.navigationItem.backBarButtonItem = nil;
}

- (void)viewDidDisappear:(BOOL)animated
{    
    // Blank the web view if we're leaving for good. Otherwise we get weirdness like videos
    // continuing to play their sound after the user switches to a different thread.
    if (!self.navigationController) {
        [self.postsView clearAllPosts];
    }
    [super viewDidDisappear:animated];
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
        [self stopObservingScrollViewContentSize];
    } else if ([keyPath isEqualToString:@"thread.seenPosts"]) {
        [self.postsView reloadData];
    }
}

static char KVOContext;

- (void)stopObservingScrollViewContentSize
{
    if (_observingScrollViewSize) {
        [self.postsView.scrollView removeObserver:self
                                       forKeyPath:@"contentSize"
                                          context:&KVOContext];
        _observingScrollViewSize = NO;
    }
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                         duration:(NSTimeInterval)duration
{
    [self updatePullUpTriggerOffset];
    [self.jumpToPageSheet showInView:self.view behindSubview:self.bottomBar];
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
    NSArray *keys = @[ AwfulPostsViewKeys.postID, AwfulPostsViewKeys.innerHTML ];
    NSMutableDictionary *dict = [[post dictionaryWithValuesForKeys:keys] mutableCopy];
    if (post.postDate) {
        NSDateFormatter *formatter = [AwfulDateFormatters formatters].postDateFormatter;
        dict[AwfulPostsViewKeys.postDate] = [formatter stringFromDate:post.postDate];
    }
    if (post.author.username) dict[AwfulPostsViewKeys.authorName] = post.author.username;
    if (post.author.avatarURL) {
        dict[AwfulPostsViewKeys.authorAvatarURL] = [post.author.avatarURL absoluteString];
    }
    if ([post.author isEqual:post.thread.author]) {
        dict[AwfulPostsViewKeys.authorIsOriginalPoster] = @YES;
    }
    if (post.author.moderatorValue) dict[AwfulPostsViewKeys.authorIsAModerator] = @YES;
    if (post.author.administratorValue) dict[AwfulPostsViewKeys.authorIsAnAdministrator] = @YES;
    if (post.author.regdate) {
        NSDateFormatter *formatter = [AwfulDateFormatters formatters].regDateFormatter;
        dict[AwfulPostsViewKeys.authorRegDate] = [formatter stringFromDate:post.author.regdate];
    }
    dict[AwfulPostsViewKeys.hasAttachment] = @([post.attachmentID length] > 0);
    if (post.editDate) {
        NSString *editor = post.editor ? post.editor.username : @"Somebody";
        NSString *editDate = [self.editDateFormatter stringFromDate:post.editDate];
        NSString *message = [NSString stringWithFormat:@"%@ fucked around with this message on %@",
                             editor, editDate];
        dict[AwfulPostsViewKeys.editMessage] = message;
    }
    dict[AwfulPostsViewKeys.beenSeen] = @(post.beenSeen);
    return dict;
}

- (NSDateFormatter *)editDateFormatter
{
    if (_editDateFormatter) return _editDateFormatter;
    _editDateFormatter = [NSDateFormatter new];
    // Jan 2, 2003 around 4:05
    _editDateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
    _editDateFormatter.dateFormat = @"MMM d, yyy 'around' HH:mm";
    return _editDateFormatter;
}

- (NSString *)advertisementHTMLForPostsView:(AwfulPostsView *)postsView
{
    return self.advertisementHTML;
}

- (void)postsView:(AwfulPostsView *)postsView didTapLinkToURL:(NSURL *)url
{
    if ([url awfulURL]) {
        [[UIApplication sharedApplication] openURL:[url awfulURL]];
    } else if (![url opensInBrowser]) {
        [[UIApplication sharedApplication] openURL:url];
    } else {
        [self openURLInBuiltInBrowser:url];
    }
}

- (void)openURLInBuiltInBrowser:(NSURL *)url
{
    AwfulBrowserViewController *browser = [AwfulBrowserViewController new];
    browser.URL = url;
    browser.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:browser animated:YES];
    UIBarButtonItem *back = [[UIBarButtonItem alloc] initWithTitle:@"Back"
                                                             style:UIBarButtonItemStyleBordered
                                                            target:nil
                                                            action:NULL];
    self.navigationItem.backBarButtonItem = back;
}

- (NSArray *)whitelistedSelectorsForPostsView:(AwfulPostsView *)postsView
{
    return @[
        @"showActionsForPostAtIndex:fromRectDictionary:",
        @"previewImageAtURLString:",
        @"showMenuForLinkWithURLString:fromRectDictionary:"
    ];
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
    NSString *possessiveUsername = [NSString stringWithFormat:@"%@'s", post.author.username];
    if ([post.author.username isEqualToString:[AwfulSettings settings].username]) {
        possessiveUsername = @"Your";
    }
    NSString *title = [NSString stringWithFormat:@"%@ Post", possessiveUsername];
    AwfulActionSheet *sheet = [[AwfulActionSheet alloc] initWithTitle:title];
    if ([post editableByUserWithID:[AwfulSettings settings].userID]) {
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
                 AwfulReplyComposeViewController *reply = [AwfulReplyComposeViewController new];
                 reply.delegate = self;
                 [reply editPost:post text:text];
                 UINavigationController *nav = [reply enclosingNavigationController];
                 [self presentViewController:nav animated:YES completion:nil];
             }];
        }];
    }
    if (!self.thread.isClosedValue) {
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
                 AwfulReplyComposeViewController *reply = [AwfulReplyComposeViewController new];
                 reply.delegate = self;
                 [reply replyToThread:self.thread withInitialContents:quotedText];
                 UINavigationController *nav = [reply enclosingNavigationController];
                 [self presentViewController:nav animated:YES completion:nil];
             }];
        }];
    }
    [sheet addButtonWithTitle:@"Copy Post URL" block:^{
        NSString *url = [NSString stringWithFormat:@"http://forums.somethingawful.com/"
                         "showthread.php?threadid=%@&perpage=40&pagenumber=%@#post%@",
                         self.thread.threadID, @(self.currentPage), post.postID];
        [UIPasteboard generalPasteboard].items = @[ @{
                                                        (id)kUTTypeURL: [NSURL URLWithString:url],
                                                        (id)kUTTypePlainText: url
                                                        }];
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
                 post.thread.seenPosts = post.threadIndex;
                 [[AwfulDataStack sharedDataStack] save];
             }
         }];
    }];
    [sheet addButtonWithTitle:[NSString stringWithFormat:@"%@ Profile", possessiveUsername] block:^{
        [self showProfileWithUser:post.author];
    }];
    [sheet addCancelButtonWithTitle:@"Cancel"];
    [sheet showFromRect:rect inView:self.postsView animated:YES];
}

- (void)previewImageAtURLString:(NSString *)urlString
{
    NSURL *url = [NSURL awful_URLWithString:urlString];
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

- (void)showMenuForLinkWithURLString:(NSString *)urlString
                  fromRectDictionary:(NSDictionary *)rectDict
{
    NSURL *url = [NSURL awful_URLWithString:urlString];
    if (!url) {
        NSLog(@"could not parse URL for link long tap menu: %@", urlString);
        return;
    }
    if ([url awfulURL]) {
        [[UIApplication sharedApplication] openURL:[url awfulURL]];
        return;
    }
    if (![url opensInBrowser]) {
        [[UIApplication sharedApplication] openURL:url];
        return;
    }
    CGRect rect = CGRectMake([rectDict[@"left"] floatValue], [rectDict[@"top"] floatValue],
                             [rectDict[@"width"] floatValue], [rectDict[@"height"] floatValue]);
    if (self.postsView.scrollView.contentOffset.y < 0) {
        rect.origin.y -= self.postsView.scrollView.contentOffset.y;
    }
    AwfulActionSheet *sheet = [AwfulActionSheet new];
    sheet.title = urlString;
    [sheet addButtonWithTitle:@"Open" block:^{ [self openURLInBuiltInBrowser:url]; }];
    [sheet addButtonWithTitle:@"Open in Safari"
                        block:^{ [[UIApplication sharedApplication] openURL:url]; }];
    for (AwfulExternalBrowser *browser in [AwfulExternalBrowser installedBrowsers]) {
        if (![browser canOpenURL:url]) continue;
        [sheet addButtonWithTitle:[NSString stringWithFormat:@"Open in %@", browser.title]
                            block:^{ [browser openURL:url]; }];
    }
    [sheet addButtonWithTitle:@"Copy URL" block:^{
        [UIPasteboard generalPasteboard].items = @[ @{
            (id)kUTTypeURL: url,
            (id)kUTTypePlainText: urlString
        } ];
    }];
    [sheet addCancelButtonWithTitle:@"Cancel"];
    [sheet showFromRect:rect inView:self.postsView animated:YES];
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
    [self updateUserInterface];
}

#pragma mark - AwfulSpecificPageControllerDelegate

- (NSInteger)numberOfPagesInJumpToPageSheet:(AwfulJumpToPageSheet *)sheet
{
    return self.thread.numberOfPagesValue;
}

- (AwfulThreadPage)initialPageForJumpToPageSheet:(AwfulJumpToPageSheet *)sheet
{
    if (self.currentPage > 0) {
        return self.currentPage;
    }
    else if (self.currentPage == AwfulThreadPageLast && self.thread.numberOfPagesValue > 0) {
        return self.thread.numberOfPagesValue;
    } else {
        return 1;
    }
}

- (void)jumpToPageSheet:(AwfulJumpToPageSheet *)sheet didSelectPage:(AwfulThreadPage)page
{
    if (page != AwfulThreadPageNone) {
        [self loadPage:page];
    }
    self.jumpToPageSheet = nil;
}

#pragma mark - AwfulReplyComposeViewControllerDelegate

- (void)replyComposeController:(AwfulReplyComposeViewController *)controller
              didReplyToThread:(AwfulThread *)thread
{
    [self dismissViewControllerAnimated:YES completion:^{
        [self loadPage:AwfulThreadPageNextUnread];
    }];
}

- (void)replyComposeController:(AwfulReplyComposeViewController *)controller
                   didEditPost:(AwfulPost *)post
{
    [self dismissViewControllerAnimated:YES completion:^{
        [self loadPage:post.page];
        [self jumpToPostWithID:post.postID];
    }];
}

- (void)replyComposeControllerDidCancel:(AwfulReplyComposeViewController *)controller
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    if (!self.cachedUpdatesWhileScrolling) self.cachedUpdatesWhileScrolling = [NSMutableArray new];
    [self.topBar scrollViewWillBeginDragging:scrollView];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self.topBar scrollViewDidScroll:scrollView];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)willDecelerate
{
    if (!willDecelerate) [self processCachedUpdates];
    [self.topBar scrollViewDidEndDragging:scrollView willDecelerate:willDecelerate];
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
