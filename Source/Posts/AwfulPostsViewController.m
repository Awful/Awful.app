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
#import <QuartzCore/QuartzCore.h>
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

@property (nonatomic) BOOL observingScrollViewOffset;

@property (nonatomic) BOOL observingScrollViewSize;

@property (nonatomic) NSMutableArray *cachedUpdatesWhileScrolling;

@end


@implementation AwfulPostsViewController

- (id)init
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.hidesBottomBarWhenPushed = YES;
    }
    return self;
}

- (void)setThread:(AwfulThread *)thread
{
    if (_thread == thread) return;
    _thread = thread;
    self.title = [thread.title stringByCollapsingWhitespace];
    [self updatePageBar];
    self.postsView.stylesheetURL = StylesheetURLForForumWithID(thread.forum.forumID);
    [self updateFetchedResultsController];
}

static NSURL* StylesheetURLForForumWithID(NSString *forumID)
{
    NSArray *listOfFilenames = @[
        [NSString stringWithFormat:@"posts-view-%@.css", forumID],
        @"posts-view.css"
    ];
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

- (void)setCurrentPage:(NSInteger)currentPage
{
    if (_currentPage == currentPage) return;
    _currentPage = currentPage;
}

- (void)updateLoadingMessage
{
    if (self.currentPage == AwfulPageLast) {
        self.postsView.loadingMessage = @"Loading last page…";
    } else if (self.currentPage == AwfulPageNextUnread) {
        self.postsView.loadingMessage = @"Loading next unread post…";
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
    self.topBar.loadReadPostsButton.enabled = hiddenPosts > 0;
}

- (void)loadPage:(NSInteger)page
{
    [self.networkOperation cancel];
    NSInteger oldPage = self.currentPage;
    self.currentPage = page;
    BOOL refreshingSamePage = page > 0 && page == oldPage;
    if (!refreshingSamePage) {
        [self updateFetchedResultsController];
        [self updateLoadingMessage];
        [self updatePageBar];
        [self updateEndMessage];
        self.pullUpToRefreshControl.refreshing = NO;
        [self updatePullForNextPageLabel];
        self.postsView.scrollView.contentOffset = CGPointZero;
        self.advertisementHTML = nil;
        self.hiddenPosts = 0;
        [self.postsView reloadData];
    }
    // This blockSelf exists entirely so we capture self in the block, which allows its use while
    // debugging. Otherwise lldb/gdb don't know anything about "self".
    __block AwfulPostsViewController *blockSelf = self;
    id op = [[AwfulHTTPClient client] listPostsInThreadWithID:self.thread.threadID
                                                       onPage:page
                                                      andThen:^(NSError *error, NSArray *posts,
                                                                NSString *advertisementHTML)
    {
        // Since we load cached pages where possible, things can get out of order if we change
        // pages quickly. If the callback comes in after we've moved away from the requested page,
        // just don't bother going any further. We have the data for later.
        if (page != self.currentPage) return;
        if (error) {
            if (self.postsView.loadingMessage) {
                self.postsView.loadingMessage = nil;
                if (![[self.pageBar.jumpToPageButton titleForState:UIControlStateNormal] length]) {
                    [self.pageBar.jumpToPageButton setTitle:@"Page ? of ?"
                                                   forState:UIControlStateNormal];
                }
            }
            [AwfulAlertView showWithTitle:@"Could Not Load Page" error:error buttonTitle:@"OK"];
            return;
        }
        self.currentPage = [[posts lastObject] threadPageValue];
        self.advertisementHTML = advertisementHTML;
        if (page == AwfulPageNextUnread) {
            NSUInteger firstUnread = [posts indexOfObjectPassingTest:^BOOL(AwfulPost *post,
                                                                           NSUInteger _, BOOL *__)
            {
                return !post.beenSeenValue;
            }];
            if (firstUnread != NSNotFound) self.hiddenPosts = firstUnread;
        }
        if (!self.fetchedResultsController) {
            [self updateFetchedResultsController];
            [self.postsView reloadData];
        }
        [self updateLoadingMessage];
        [self updatePageBar];
        [self updateEndMessage];
        [self updatePullForNextPageLabel];
        [blockSelf markPostsAsBeenSeen];
    }];
    self.networkOperation = op;
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
    if (self.currentPage < self.thread.numberOfPagesValue) {
        [self loadPage:self.currentPage + 1];
    } else {
        [self loadPage:self.currentPage];
    }
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
                         "showthread.php?threadid=%@&pagenumber=%@",
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
                         "showthread.php?threadid=%@&pagenumber=%@#post%@",
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
        self.pullUpToRefreshControl.triggerOffset = 45;
    } else {
        self.pullUpToRefreshControl.triggerOffset = 25;
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
    self.topBar.backgroundColor = [AwfulTheme currentTheme].postsViewTopBarBackgroundColor;
    NSArray *buttons = @[ self.topBar.goToForumButton, self.topBar.loadReadPostsButton,
                          self.topBar.scrollToBottomButton ];
    for (UIButton *button in buttons) {
        [button setTitleColor:[AwfulTheme currentTheme].postsViewTopBarButtonTextColor
                     forState:UIControlStateNormal];
        [button setTitleShadowColor:[UIColor whiteColor]
                           forState:UIControlStateNormal];
        [button setTitleColor:[AwfulTheme currentTheme].postsViewTopBarButtonDisabledTextColor
                     forState:UIControlStateDisabled];
    }
    self.postsView.dark = [AwfulSettings settings].darkTheme;
}

#pragma mark - UIViewController

- (void)setTitle:(NSString *)title
{
    [super setTitle:title];
    self.navigationItem.titleLabel.text = title;
}

- (void)loadView
{
    self.view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.view.backgroundColor = [AwfulTheme currentTheme].postsViewBackgroundColor;
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
    postsView.showAvatars = [AwfulSettings settings].showAvatars;
    postsView.showImages = [AwfulSettings settings].showImages;
    if (AwfulSettings.settings.highlightOwnMentions) {
        postsView.highlightMentionUsername = [AwfulSettings settings].username;
    }
    if (AwfulSettings.settings.highlightOwnQuotes) {
        postsView.highlightQuoteUsername = [AwfulSettings settings].username;
    }
    self.postsView = postsView;
    [self.view addSubview:postsView];
    
    TopBarView *topBar = [TopBarView new];
    topBar.frame = CGRectMake(0, -44, self.view.frame.size.width, 44);
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
    postsView.scrollView.contentInset = UIEdgeInsetsMake(44, 0, 0, 0);
    [self keepTopBarHiddenOnFirstView];
    postsView.scrollView.delegate = self;
    
    AwfulPullToRefreshControl *refresh;
    refresh = [[AwfulPullToRefreshControl alloc] initWithDirection:AwfulScrollViewPullUp];
    [refresh addTarget:self
                action:@selector(loadNextPageOrRefresh)
      forControlEvents:UIControlEventValueChanged];
    refresh.backgroundColor = postsView.backgroundColor;
    refresh.gradient.colors = @[
        (id)[UIColor colorWithWhite:0 alpha:0.3].CGColor,
        (id)[UIColor colorWithWhite:0 alpha:0].CGColor
    ];
    refresh.gradient.endPoint = CGPointMake(0.5, 0.5);
    [self.postsView.scrollView addSubview:refresh];
    self.pullUpToRefreshControl = refresh;
    [self updatePullUpTriggerOffset];
    
    [self.view bringSubviewToFront:self.pageBar];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self retheme];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(currentThemeChanged:)
                                                 name:AwfulThemeDidChangeNotification
                                               object:nil];
}

- (void)currentThemeChanged:(NSNotification *)note
{
    [self retheme];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AwfulThemeDidChangeNotification
                                                  object:nil];
    // Blank the web view if we're leaving for good. Otherwise we get weirdness like videos
    // continuing to play their sound after the user switches to a different thread.
    if (!self.navigationController) {
        [self.postsView clearAllPosts];
        [self markPostsAsBeenSeen];
    }
    [super viewDidDisappear:animated];
}

// We want to hide the top bar until the user reveals it. Unfortunately, AwfulPostsView's
// scrollView changes its contentSize at some arbitrary point (when it loads the posts we send it),
// which changes the contentOffset to reveal the top bar.
//
// Here, we simply override that first attempt to set the contentOffset too high.
- (void)keepTopBarHiddenOnFirstView
{
    _observingScrollViewOffset = YES;
    [self.postsView.scrollView addObserver:self
                                forKeyPath:@"contentOffset"
                                   options:NSKeyValueObservingOptionNew
                                   context:&KVOContext];
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
    if ([keyPath isEqualToString:@"contentOffset"]) {
        CGPoint offset = [change[NSKeyValueChangeNewKey] CGPointValue];
        if (offset.y < 0) {
            [object setContentOffset:CGPointZero];
            [object removeObserver:self forKeyPath:keyPath context:context];
            _observingScrollViewOffset = NO;
        }
    } else if ([keyPath isEqualToString:@"contentSize"]) {
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

- (void)dealloc
{
    if (_observingScrollViewOffset) {
        [self.postsView.scrollView removeObserver:self
                                       forKeyPath:@"contentOffset"
                                          context:&KVOContext];
    }
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
    // TODO intercept links to forums, threads, posts and show in-app.
    // N.B. Some links may have no host and go to showthread.php
    [[UIApplication sharedApplication] openURL:url];
}

- (void)showActionsForPostAtIndex:(NSNumber *)index fromRectDictionary:(NSDictionary *)rectDict
{
    NSInteger unboxed = [index integerValue] + self.hiddenPosts;
    AwfulPost *post = self.fetchedResultsController.fetchedObjects[unboxed];
    CGRect rect = CGRectMake([rectDict[@"left"] floatValue], [rectDict[@"top"] floatValue],
                             [rectDict[@"width"] floatValue], [rectDict[@"height"] floatValue]);
    [self showActionsForPost:post fromRect:rect inView:self.postsView];
}

- (void)previewImageAtURLString:(NSString *)urlString
{
    AwfulImagePreviewViewController *preview = [[AwfulImagePreviewViewController alloc]
                                                initWithURL:[NSURL URLWithString:urlString]];
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
    return self.currentPage;
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
        // TODO jump to post
        [self loadPage:post.threadPageValue];
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
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)willDecelerate
{
    if (willDecelerate) return;
    [self processCachedUpdates];
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
    [goToForumButton setTitle:@"Go To\nForum" forState:UIControlStateNormal];
    goToForumButton.accessibilityLabel = @"Go to forum";
    goToForumButton.accessibilityHint = @"Opens this thread's forum";
    [goToForumButton setImage:[UIImage imageNamed:@"go-to-forum.png"]
                     forState:UIControlStateNormal];
    _goToForumButton = goToForumButton;
    
    UIButton *loadReadPostsButton = [self makeButton];
    [loadReadPostsButton setTitle:@"Load Read\nPosts" forState:UIControlStateNormal];
    loadReadPostsButton.accessibilityLabel = @"Load read posts";
    [loadReadPostsButton setImage:[UIImage imageNamed:@"load-read-posts.png"]
                         forState:UIControlStateNormal];
    _loadReadPostsButton = loadReadPostsButton;
    
    UIButton *scrollToBottomButton = [self makeButton];
    [scrollToBottomButton setTitle:@"Scroll To\nBottom" forState:UIControlStateNormal];
    scrollToBottomButton.accessibilityLabel = @"Scroll to bottom";
    [scrollToBottomButton setImage:[UIImage imageNamed:@"scroll-to-bottom.png"]
                          forState:UIControlStateNormal];
    _scrollToBottomButton = scrollToBottomButton;
    
    return self;
}

- (UIButton *)makeButton
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.titleEdgeInsets = UIEdgeInsetsMake(0, 6, 0, 0);
    button.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    button.titleLabel.numberOfLines = 2;
    button.titleLabel.shadowOffset = CGSizeMake(0, 1);
    button.imageEdgeInsets = UIEdgeInsetsMake(0, 10, 0, 0);
    [self addSubview:button];
    return button;
}

- (void)layoutSubviews
{
    CGFloat buttonWidth = floorf(self.bounds.size.width / 3);
    CGFloat x = floorf(self.bounds.size.width - buttonWidth * 3) / 2;
    
    self.goToForumButton.frame = CGRectMake(x, 0, buttonWidth, self.bounds.size.height);
    x += buttonWidth;
    self.loadReadPostsButton.frame = CGRectMake(x, 0, buttonWidth, self.bounds.size.height);
    x += buttonWidth;
    self.scrollToBottomButton.frame = CGRectMake(x, 0, buttonWidth, self.bounds.size.height);
}

@end
