//  AwfulPostsViewController.m
//
//  Copyright 2010 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPostsViewController.h"
#import "AwfulActionSheet.h"
#import "AwfulAlertView.h"
#import "AwfulAppDelegate.h"
#import "AwfulBrowserViewController.h"
#import "AwfulDateFormatters.h"
#import "AwfulExternalBrowser.h"
#import "AwfulHTTPClient.h"
#import "AwfulIconActionSheet.h"
#import "AwfulImagePreviewViewController.h"
#import "AwfulJumpToPageController.h"
#import "AwfulLoadingView.h"
#import "AwfulModels.h"
#import "AwfulNewPrivateMessageViewController.h"
#import "AwfulPageSettingsViewController.h"
#import "AwfulPageTopBar.h"
#import "AwfulPostsView.h"
#import "AwfulPostViewModel.h"
#import "AwfulProfileViewController.h"
#import "AwfulRapSheetViewController.h"
#import "AwfulReadLaterService.h"
#import "AwfulReplyViewController.h"
#import "AwfulSettings.h"
#import "AwfulThemeLoader.h"
#import "AwfulForumThreadTableViewController.h"
#import "AwfulUIKitAndFoundationCategories.h"
#import <GRMustache/GRMustache.h>
#import <SVProgressHUD/SVProgressHUD.h>
#import <SVPullToRefresh/SVPullToRefresh.h>
#import <WYPopoverController/WYPopoverController.h>

@interface AwfulPostsViewController () <AwfulPostsViewDelegate, AwfulJumpToPageControllerDelegate, NSFetchedResultsControllerDelegate, AwfulComposeTextViewControllerDelegate, UIScrollViewDelegate, WYPopoverControllerDelegate, UIViewControllerRestoration, AwfulPageSettingsViewControllerDelegate>

@property (nonatomic) NSFetchedResultsController *fetchedResultsController;

@property (weak, nonatomic) NSOperation *networkOperation;

@property (nonatomic) AwfulPageTopBar *topBar;
@property (strong, nonatomic) AwfulPostsView *postsView;
@property (strong, nonatomic) WYPopoverController *jumpToPagePopover;
@property (strong, nonatomic) WYPopoverController *pageSettingsPopover;
@property (nonatomic) UIBarButtonItem *composeItem;

@property (strong, nonatomic) UIBarButtonItem *settingsItem;
@property (strong, nonatomic) UIBarButtonItem *backItem;
@property (strong, nonatomic) UIBarButtonItem *currentPageItem;
@property (strong, nonatomic) UIBarButtonItem *forwardItem;
@property (strong, nonatomic) UIBarButtonItem *actionsItem;

@property (nonatomic) NSInteger hiddenPosts;
@property (strong, nonatomic) AwfulPost *topPostAfterLoad;
@property (copy, nonatomic) NSString *advertisementHTML;
@property (nonatomic) GRMustacheTemplate *postTemplate;
@property (nonatomic) AwfulLoadingView *loadingView;

@property (nonatomic) BOOL observingScrollViewSize;
@property (nonatomic) BOOL observingThreadSeenPosts;

@property (nonatomic) NSMutableArray *cachedUpdatesWhileScrolling;

@property (strong, nonatomic) AwfulReplyViewController *replyViewController;

@end

@implementation AwfulPostsViewController

- (id)initWithThread:(AwfulThread *)thread author:(AwfulUser *)author
{
    if (!(self = [super initWithNibName:nil bundle:nil])) return nil;
    _thread = thread;
    _author = author;
    self.restorationClass = self.class;
    self.navigationItem.rightBarButtonItem = self.composeItem;
    self.toolbarItems = @[ self.settingsItem,
                           [UIBarButtonItem flexibleSpace],
                           self.backItem,
                           self.currentPageItem,
                           self.forwardItem,
                           [UIBarButtonItem flexibleSpace],
                           self.actionsItem ];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(settingsDidChange:)
                                                 name:AwfulSettingsDidChangeNotification
                                               object:nil];
    return self;
}

- (id)initWithThread:(AwfulThread *)thread
{
    return [self initWithThread:thread author:nil];
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
    if (!self.replyViewController) {
        self.replyViewController = [[AwfulReplyViewController alloc] initWithThread:self.thread quotedText:nil];
        self.replyViewController.delegate = self;
        self.replyViewController.restorationIdentifier = @"Reply composition";
    }
    UINavigationController *nav = [self.replyViewController enclosingNavigationController];
    nav.restorationIdentifier = @"Reply composition navigation controller";
    [self presentViewController:nav animated:YES completion:nil];
}

- (UIBarButtonItem *)settingsItem
{
    if (_settingsItem) return _settingsItem;
    _settingsItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"font-size"]
                                                     style:UIBarButtonItemStylePlain
                                                    target:self
                                                    action:@selector(toggleSettings:)];
    return _settingsItem;
}

- (void)toggleSettings:(UIBarButtonItem *)sender
{
    AwfulPageSettingsViewController *settings = [AwfulPageSettingsViewController new];
    settings.delegate = self;
    settings.themes = [[AwfulThemeLoader sharedLoader] themesForForumWithID:self.thread.forum.forumID];
    settings.selectedTheme = [AwfulTheme currentThemeForForum:self.thread.forum];
    self.pageSettingsPopover = [[WYPopoverController alloc] initWithContentViewController:settings];
    self.pageSettingsPopover.delegate = self;
    [self.pageSettingsPopover presentPopoverFromBarButtonItem:sender
                                     permittedArrowDirections:WYPopoverArrowDirectionAny
                                                     animated:YES];
}

- (UIBarButtonItem *)backItem
{
    if (_backItem) return _backItem;
    _backItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"arrowleft"]
                                                 style:UIBarButtonItemStylePlain
                                                target:self
                                                action:@selector(goToPreviousPage)];
    return _backItem;
}

- (void)goToPreviousPage
{
    if (self.page > 1) {
        self.page--;
    }
}

- (UIBarButtonItem *)currentPageItem
{
    if (_currentPageItem) return _currentPageItem;
    _currentPageItem = [[UIBarButtonItem alloc] initWithTitle:@""
                                                        style:UIBarButtonItemStylePlain
                                                       target:self
                                                       action:@selector(toggleJumpToPageSheet:)];
    _currentPageItem.possibleTitles = [NSSet setWithObject:@"2345 / 2345"];
    return _currentPageItem;
}

- (void)toggleJumpToPageSheet:(UIBarButtonItem *)sender
{
    if (self.loadingView) return;
    if (!self.jumpToPagePopover) {
        NSInteger relevantNumberOfPages = [self relevantNumberOfPagesInThread];
        if (relevantNumberOfPages < 1) return;
        AwfulJumpToPageController *jump = [[AwfulJumpToPageController alloc] initWithDelegate:self];
        jump.numberOfPages = relevantNumberOfPages;
        if (self.page > 0) {
            jump.selectedPage = self.page;
        }
        else if (self.page == AwfulThreadPageLast && relevantNumberOfPages > 0) {
            jump.selectedPage = relevantNumberOfPages;
        }
        UINavigationController *nav = [jump enclosingNavigationController];
        self.jumpToPagePopover = [[WYPopoverController alloc] initWithContentViewController:nav];
        self.jumpToPagePopover.delegate = self;
    }
    [self.jumpToPagePopover presentPopoverFromBarButtonItem:sender
                                   permittedArrowDirections:WYPopoverArrowDirectionAny
                                                   animated:YES];
}

- (UIBarButtonItem *)forwardItem
{
    if (_forwardItem) return _forwardItem;
    _forwardItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"arrowright"]
                                                    style:UIBarButtonItemStylePlain
                                                   target:self
                                                   action:@selector(goToNextPage)];
    return _forwardItem;
}

- (void)goToNextPage
{
    if (self.page < [self relevantNumberOfPagesInThread]) {
        self.page++;
    }
}

- (UIBarButtonItem *)actionsItem
{
    if (_actionsItem) return _actionsItem;
    _actionsItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                                 target:self
                                                                 action:@selector(showThreadActionsFromBarButtonItem:)];
    return _actionsItem;
}

- (void)showThreadActionsFromBarButtonItem:(UIBarButtonItem *)barButtonItem
{
    AwfulIconActionSheet *sheet = [AwfulIconActionSheet new];
    sheet.title = self.title;
    AwfulIconActionItem *copyURL = [AwfulIconActionItem itemWithType:AwfulIconActionItemTypeCopyURL action:^{
        NSString *url = [NSString stringWithFormat:@"http://forums.somethingawful.com/"
                         "showthread.php?threadid=%@&perpage=40&pagenumber=%@",
                         self.thread.threadID, @(self.page)];
        [AwfulSettings settings].lastOfferedPasteboardURL = url;
        [UIPasteboard generalPasteboard].items = @[ @{ (id)kUTTypeURL: [NSURL URLWithString:url],
                                                       (id)kUTTypePlainText: url
                                                       }];
    }];
    copyURL.title = @"Copy Thread URL";
    [sheet addItem:copyURL];
    [sheet addItem:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeVote action:^{
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
        [vote showFromBarButtonItem:barButtonItem animated:NO];
    }]];
    
    AwfulIconActionItemType bookmarkItemType;
    if (self.thread.bookmarked) {
        bookmarkItemType = AwfulIconActionItemTypeRemoveBookmark;
    } else {
        bookmarkItemType = AwfulIconActionItemTypeAddBookmark;
    }
    [sheet addItem:[AwfulIconActionItem itemWithType:bookmarkItemType action:^{
        [[AwfulHTTPClient client] setThreadWithID:self.thread.threadID
                                     isBookmarked:!self.thread.bookmarked
                                          andThen:^(NSError *error)
         {
             if (error) {
                 NSLog(@"error %@bookmarking thread %@: %@",
                       self.thread.bookmarked ? @"un" : @"", self.thread.threadID, error);
             } else {
                 NSString *status = @"Removed Bookmark";
                 if (self.thread.bookmarked) {
                     status = @"Added Bookmark";
                 }
                 [SVProgressHUD showSuccessWithStatus:status];
             }
         }];
    }]];
    [sheet showFromBarButtonItem:barButtonItem animated:NO];
}

- (void)settingsDidChange:(NSNotification *)note
{
    if (![self isViewLoaded]) return;
    NSArray *importantKeys = @[
        AwfulSettingsKeys.showAvatars,
        AwfulSettingsKeys.showImages,
        AwfulSettingsKeys.username
    ];
    NSArray *keys = note.userInfo[AwfulSettingsDidChangeSettingsKey];
    if ([keys firstObjectCommonWithArray:importantKeys]) {
        [self configurePostsViewSettings];
    }
}

- (void)themeDidChange
{
    [super themeDidChange];
    [self configurePostsViewSettings];
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
    self.postsView.stylesheet = AwfulTheme.currentTheme[@"postsViewCSS"];
    self.replyViewController = nil;
}

- (NSArray *)posts
{
    return self.fetchedResultsController.fetchedObjects;
}

- (void)updateFetchedResultsController
{
    if (!self.thread || self.page < 1) {
        self.fetchedResultsController.delegate = nil;
        self.fetchedResultsController = nil;
        return;
    }
    
    NSFetchRequest *request = self.fetchedResultsController.fetchRequest;
    if (!request) {
        request = [NSFetchRequest fetchRequestWithEntityName:[AwfulPost entityName]];
    }
    NSInteger lowIndex = (self.page - 1) * 40 + 1;
    NSInteger highIndex = self.page * 40;
    NSString *indexKey;
    if (self.author) {
        indexKey = @"singleUserIndex";
    } else {
        indexKey = @"threadIndex";
    }
    request.predicate = [NSPredicate predicateWithFormat:@"thread = %@ AND %d <= %K AND %K <= %d",
                         self.thread, lowIndex, indexKey, indexKey, highIndex];
    if (self.author) {
        NSPredicate *and = [NSPredicate predicateWithFormat:@"author.userID = %@", self.author.userID];
        request.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:
                             @[ request.predicate, and ]];
    }
    request.sortDescriptors = @[ [NSSortDescriptor sortDescriptorWithKey:indexKey ascending:YES] ];
    if (!self.fetchedResultsController) {
        NSManagedObjectContext *context = self.thread.managedObjectContext;
        NSFetchedResultsController *controller;
        controller = [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                                         managedObjectContext:context
                                                           sectionNameKeyPath:nil
                                                                    cacheName:nil];
        controller.delegate = self;
        self.fetchedResultsController = controller;
    }
    
    NSError *error;
    BOOL ok = [self.fetchedResultsController performFetch:&error];
    if (!ok) {
        NSLog(@"error fetching posts: %@", error);
    }
}

- (void)updateUserInterface
{
    self.title = [self.thread.title stringByCollapsingWhitespace];
    
    if (self.page == AwfulThreadPageLast ||
        self.page == AwfulThreadPageNextUnread ||
        [self.fetchedResultsController.fetchedObjects count] == 0)
    {
        [self setLoadingMessage:@"Loading…"];
    } else {
        [self clearLoadingMessage];
    }
    
    self.topBar.scrollToBottomButton.enabled = [self.posts count] > 0;
    self.topBar.loadReadPostsButton.enabled = self.hiddenPosts > 0;
    
    NSInteger relevantNumberOfPages = [self relevantNumberOfPagesInThread];
    if (self.page > 0 && self.page >= relevantNumberOfPages) {
        self.postsView.endMessage = @"End of the thread";
    } else {
        self.postsView.endMessage = nil;
    }
    
    SVPullToRefreshView *refresh = self.postsView.scrollView.pullToRefreshView;
    if (relevantNumberOfPages > self.page) {
        [refresh setTitle:@"Pull for next page…" forState:SVPullToRefreshStateStopped];
        [refresh setTitle:@"Release for next page…" forState:SVPullToRefreshStateTriggered];
        [refresh setTitle:@"Loading next page…" forState:SVPullToRefreshStateLoading];
    } else {
        [refresh setTitle:@"Pull to refresh…" forState:SVPullToRefreshStateStopped];
        [refresh setTitle:@"Release to refresh…" forState:SVPullToRefreshStateTriggered];
        [refresh setTitle:@"Refreshing…" forState:SVPullToRefreshStateLoading];
    }
    
    self.backItem.enabled = self.page > 1;
    if (self.page > 0 && relevantNumberOfPages > 0) {
        self.currentPageItem.title = [NSString stringWithFormat:@"%zd / %zd", self.page, relevantNumberOfPages];
    } else {
        self.currentPageItem.title = @"";
    }
    self.forwardItem.enabled = self.page > 0 && self.page < relevantNumberOfPages;
    self.composeItem.enabled = !self.thread.closed;
}

- (void)setLoadingMessage:(NSString *)message
{
    if (!self.loadingView) {
		AwfulTheme *theme = [AwfulTheme currentThemeForForum:self.thread.forum];
        self.loadingView = [AwfulLoadingView loadingViewForTheme:theme];
    }
    self.loadingView.message = message;
    [self.postsView addSubview:self.loadingView];
}

- (void)clearLoadingMessage
{
    [self.loadingView removeFromSuperview];
    self.loadingView = nil;
}

- (void)configurePostsViewSettings
{
    AwfulTheme *theme = [AwfulTheme currentThemeForForum:self.thread.forum];
	self.postsView.backgroundColor = theme[@"backgroundColor"];
    self.view.backgroundColor = theme[@"backgroundColor"];
	
    self.postsView.showAvatars = [AwfulSettings settings].showAvatars;
    self.postsView.showImages = [AwfulSettings settings].showImages;
    self.postsView.highlightMentionUsername = [AwfulSettings settings].username;
    self.postsView.highlightQuoteUsername = [AwfulSettings settings].username;
    self.postsView.stylesheet = theme[@"postsViewCSS"];
    if (self.loadingView) {
        NSString *message = self.loadingView.message;
        [self setLoadingMessage:message];
    }
}

- (void)setHiddenPosts:(NSInteger)hiddenPosts
{
    if (_hiddenPosts == hiddenPosts) return;
    _hiddenPosts = hiddenPosts;
    [self updateUserInterface];
}

- (void)setPage:(AwfulThreadPage)page
{
    AwfulThreadPage oldPage = _page;
    _page = page;
    if (page == oldPage) {
        [self refreshCurrentPage];
    } else {
        [self loadFetchAndShowPostsFromPage:page];
    }
}

- (void)loadFetchAndShowPostsFromPage:(AwfulThreadPage)page
{
    [self prepareForLoad];
    if (page != AwfulThreadPageNone) {
        [self prepareForNewPage];
    }
    [self fetchPage:page completionHandler:^(NSError *error) {
        if (error) {
            // Poor man's offline mode.
            if (AwfulHTTPClient.client.reachable || ![error.domain isEqualToString:NSURLErrorDomain]) {
                [AwfulAlertView showWithTitle:@"Could Not Load Page" error:error buttonTitle:@"OK"];
            }
        }
    }];
}

- (void)loadCachedPostsFromPage:(AwfulThreadPage)page
{
    _page = page;
    [self prepareForLoad];
    if (page > 0) {
        [self prepareForNewPage];
    }
    [self.postsView reloadData];
    if (self.topPostAfterLoad) {
        self.topPost = self.topPostAfterLoad;
        self.topPostAfterLoad = nil;
    }
    [self updateUserInterface];
    [self startObservingThreadSeenPosts];
    [self clearLoadingMessage];
}

- (void)refreshCurrentPage
{
    [self prepareForLoad];
    [self fetchPage:self.page completionHandler:^(NSError *error) {
        if (error) {
            [AwfulAlertView showWithTitle:@"Could Not Load Page" error:error buttonTitle:@"OK"];
        }
    }];
}

- (void)prepareForLoad
{
    [self stopObservingThreadSeenPosts];
    [self.networkOperation cancel];
    self.topPostAfterLoad = nil;
}

- (void)prepareForNewPage
{
    self.cachedUpdatesWhileScrolling = nil;
    [self updateFetchedResultsController];
    [self.postsView.scrollView.pullToRefreshView stopAnimating];
    [self updateUserInterface];
    [self.postsView.scrollView setContentOffset:CGPointZero animated:NO];
    self.advertisementHTML = nil;
    self.hiddenPosts = 0;
    [self.postsView reloadData];
}

- (void)fetchPage:(AwfulThreadPage)page completionHandler:(void (^)(NSError *error))completionHandler
{
    __weak __typeof__(self) weakSelf = self;
    id op = [[AwfulHTTPClient client] listPostsInThreadWithID:self.thread.threadID
                                                       onPage:page
                                                 singleUserID:self.author.userID
                                                      andThen:^(NSError *error,
                                                                NSArray *posts,
                                                                NSUInteger firstUnreadPost,
                                                                NSString *advertisementHTML)
             {
                 __typeof__(self) self = weakSelf;
                 
                 // Since we load cached pages where possible, things can get out of order if we change
                 // pages quickly. If the callback comes in after we've moved away from the requested page,
                 // just don't bother going any further. We have the data for later.
                 if (page != self.page) return;
                 
                 BOOL wasLoading = !!self.loadingView;
                 if (error) {
                     if (wasLoading) {
                         [self clearLoadingMessage];
                         // TODO this is stupid, relying on UI state
                         if (self.currentPageItem.title.length == 0) {
                             if ([self relevantNumberOfPagesInThread] > 0) {
                                 NSString *title = [NSString stringWithFormat:@"Page ? of %zd", [self relevantNumberOfPagesInThread]];
                                 self.currentPageItem.title = title;
                             } else {
                                 self.currentPageItem.title = @"Page ? of ?";
                             }
                         }
                     }
                     completionHandler(error);
                     return;
                 }
                 AwfulPost *lastPost = [posts lastObject];
                 if (lastPost) {
                     self.thread = [lastPost thread];
                     _page = self.author ? lastPost.singleUserPage : lastPost.page;
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
                 if (self.topPostAfterLoad) {
                     self.topPost = self.topPostAfterLoad;
                     self.topPostAfterLoad = nil;
                 } else if (wasLoading) {
                     UIScrollView *scrollView = self.postsView.scrollView;
                     [scrollView setContentOffset:CGPointMake(0, -scrollView.contentInset.top) animated:NO];
                 }
                 [self updateUserInterface];
                 if (self.thread.seenPosts < lastPost.threadIndex) {
                     self.thread.seenPosts = lastPost.threadIndex;
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

- (void)setTopPost:(AwfulPost *)topPost
{
    if (self.loadingView) {
        self.topPostAfterLoad = topPost;
        return;
    }
    if (self.hiddenPosts > 0) {
        NSUInteger i = [self.posts indexOfObjectPassingTest:^BOOL(AwfulPost *post, NSUInteger _, BOOL *__) {
            return [post isEqual:topPost];
        }];
        if (i < (NSUInteger)self.hiddenPosts) [self showHiddenSeenPosts];
    }
    [self.postsView jumpToElementWithID:topPost.postID];
}

- (void)loadNextPageOrRefresh
{
    if ([self relevantNumberOfPagesInThread] > self.page) {
        self.page++;
    } else {
        [self refreshCurrentPage];
    }
}

- (void)showProfileWithUser:(AwfulUser *)user
{
    AwfulProfileViewController *profile = [[AwfulProfileViewController alloc] initWithUser:user];
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                          target:self
                                                                          action:@selector(doneWithProfile)];
    profile.navigationItem.leftBarButtonItem = item;
    [self presentViewController:[profile enclosingNavigationController] animated:YES completion:nil];
}

- (void)doneWithProfile
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)showRapSheetWithUser:(AwfulUser *)user
{
    AwfulRapSheetViewController *rapSheet = [[AwfulRapSheetViewController alloc] initWithUser:user];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self presentViewController:[rapSheet enclosingNavigationController] animated:YES completion:nil];
    } else {
        UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithTitle:@"Back"
                                                                 style:UIBarButtonItemStylePlain
                                                                target:nil
                                                                action:nil];
        self.navigationItem.backBarButtonItem = item;
        [self.navigationController pushViewController:rapSheet animated:YES];
    }
}

#pragma mark - UIViewController

- (void)setTitle:(NSString *)title
{
    [super setTitle:title];
    self.navigationItem.titleLabel.text = title;
}

- (void)loadView
{
    self.postsView = [AwfulPostsView new];
    self.postsView.delegate = self;
    self.postsView.scrollView.delegate = self;
    self.postsView.autoresizingMask = (UIViewAutoresizingFlexibleWidth |
                                       UIViewAutoresizingFlexibleHeight);
    self.view = self.postsView;
    
    self.topBar = [AwfulPageTopBar new];
    self.topBar.frame = CGRectMake(0, -40, CGRectGetWidth(self.view.frame), 40);
    [self.topBar.goToForumButton addTarget:self action:@selector(goToParentForum)
                          forControlEvents:UIControlEventTouchUpInside];
    [self.topBar.loadReadPostsButton addTarget:self action:@selector(showHiddenSeenPosts)
                              forControlEvents:UIControlEventTouchUpInside];
    self.topBar.loadReadPostsButton.enabled = self.hiddenPosts > 0;
    [self.topBar.scrollToBottomButton addTarget:self action:@selector(scrollToBottom)
                               forControlEvents:UIControlEventTouchUpInside];
    [self.postsView.scrollView addSubview:self.topBar];
    
    self.topBar.backgroundColor = [UIColor colorWithRed:0.973 green:0.973 blue:0.973 alpha:1];
    NSArray *buttons = @[ self.topBar.goToForumButton, self.topBar.loadReadPostsButton,
                          self.topBar.scrollToBottomButton ];
    for (UIButton *button in buttons) {
        [button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        [button setTitleShadowColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [button setTitleColor:[UIColor lightGrayColor] forState:UIControlStateDisabled];
        button.backgroundColor = [UIColor colorWithRed:0.973 green:0.973 blue:0.973 alpha:1];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // Doing this here avoids SVPullToRefresh's poor interaction with automaticallyAdjustsScrollViewInsets.
    [self.postsView.scrollView addPullToRefreshWithActionHandler:^{ [self loadNextPageOrRefresh]; }
                                                        position:SVPullToRefreshPositionBottom];
}

- (NSInteger)relevantNumberOfPagesInThread
{
    if (self.author) {
        return [self.thread numberOfPagesForSingleUser:self.author];
    } else {
        return self.thread.numberOfPages;
    }
}

- (void)goToParentForum
{
    NSString *url = [NSString stringWithFormat:@"awful://forums/%@", self.thread.forum.forumID];
    [AwfulAppDelegate.instance openAwfulURL:[NSURL URLWithString:url]];
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
    if (_observingScrollViewSize && [self isViewLoaded]) {
        [self.postsView.scrollView removeObserver:self
                                       forKeyPath:@"contentSize"
                                          context:&KVOContext];
        _observingScrollViewSize = NO;
    }
}

#pragma mark - AwfulPostsViewDelegate

- (NSInteger)numberOfPostsInPostsView:(AwfulPostsView *)postsView
{
    return [[self.fetchedResultsController fetchedObjects] count] - self.hiddenPosts;
}

- (NSString *)postsView:(AwfulPostsView *)postsView renderedPostAtIndex:(NSInteger)index
{
    AwfulPost *post = self.fetchedResultsController.fetchedObjects[index + self.hiddenPosts];
    NSError *error;
    NSString *html = [self.postTemplate renderObject:[AwfulPostViewModel newWithPost:post]
                                               error:&error];
    if (!html) {
        NSLog(@"error rendering post at index %@: %@", @(index), error);
    }
    return html;
}

- (GRMustacheTemplate *)postTemplate
{
    if (_postTemplate) return _postTemplate;
    NSError *error;
    _postTemplate = [GRMustacheTemplate templateFromResource:@"Post" bundle:nil error:&error];
    if (!_postTemplate) {
        NSLog(@"error loading post template: %@", error);
    }
    return _postTemplate;
}

- (NSString *)advertisementHTMLForPostsView:(AwfulPostsView *)postsView
{
    return self.advertisementHTML;
}

- (void)postsView:(AwfulPostsView *)postsView willFollowLinkToURL:(NSURL *)url
{
    if ([url awfulURL]) {
        [[AwfulAppDelegate instance] openAwfulURL:[url awfulURL]];
    } else if ([url opensInBrowser]) {
        [self openURLInBuiltInBrowser:url];
    } else {
        [[UIApplication sharedApplication] openURL:url];
    }
}

- (void)openURLInBuiltInBrowser:(NSURL *)url
{
    AwfulBrowserViewController *browser = [AwfulBrowserViewController new];
    browser.URL = url;
    browser.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                             target:self
                                                                                             action:@selector(doneWithBrowser)];
    [self presentViewController:[browser enclosingNavigationController] animated:YES completion:nil];
}

- (void)doneWithBrowser
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)postsView:(AwfulPostsView *)postsView didReceiveSingleTapAtPoint:(CGPoint)point
{
    CGRect rect;
    NSInteger postIndex = [postsView indexOfPostWithActionButtonAtPoint:point rect:&rect];
    NSInteger usersPostIndex = [postsView indexOfPostWithUserNameAtPoint:point rect:&rect];
    if (postIndex != NSNotFound) {
        AwfulPost *post = self.fetchedResultsController.fetchedObjects[postIndex + self.hiddenPosts];
        [self showActionsForPost:post fromRect:rect];
    } else if (usersPostIndex != NSNotFound) {
        AwfulPost *post = self.fetchedResultsController.fetchedObjects[usersPostIndex + self.hiddenPosts];
        [self showActionsForUser:post.author fromRect:rect];
    }
}

- (void)showActionsForPost:(AwfulPost *)post fromRect:(CGRect)rect
{
    NSString *possessiveUsername = [NSString stringWithFormat:@"%@'s", post.author.username];
    if ([post.author.username isEqualToString:[AwfulSettings settings].username]) {
        possessiveUsername = @"Your";
    }
    AwfulIconActionSheet *sheet = [AwfulIconActionSheet new];
    sheet.title = [NSString stringWithFormat:@"%@ Post", possessiveUsername];
    [sheet addItem:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeCopyURL action:^{
        NSString *url = [NSString stringWithFormat:@"http://forums.somethingawful.com/"
                         "showthread.php?threadid=%@&perpage=40&pagenumber=%@#post%@",
                         self.thread.threadID, @(self.page), post.postID];
        [AwfulSettings settings].lastOfferedPasteboardURL = url;
        [UIPasteboard generalPasteboard].items = @[ @{
            (id)kUTTypeURL: [NSURL URLWithString:url],
            (id)kUTTypePlainText: url,
        }];
    }]];
    if (!self.author) {
        [sheet addItem:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeMarkReadUpToHere
                                                  action:^
        {
            [[AwfulHTTPClient client] markThreadWithID:self.thread.threadID
                                   readUpToPostAtIndex:[@(post.threadIndex) stringValue]
                                               andThen:^(NSError *error)
             {
                 if (error) {
                     [AwfulAlertView showWithTitle:@"Could Not Mark Read"
                                             error:error
                                       buttonTitle:@"Alright"];
                 } else {
                     [SVProgressHUD showSuccessWithStatus:@"Marked"];
                     post.thread.seenPosts = post.threadIndex;
                 }
             }];
        }]];
    }
    if (post.editable) {
        [sheet addItem:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeEditPost action:^{
            [[AwfulHTTPClient client] getTextOfPostWithID:post.postID
                                                  andThen:^(NSError *error, NSString *text)
             {
                 if (error) {
                     [AwfulAlertView showWithTitle:@"Could Not Edit Post"
                                             error:error
                                       buttonTitle:@"Alright"];
                     return;
                 }
                 self.replyViewController = [[AwfulReplyViewController alloc] initWithPost:post originalText:text];
                 self.replyViewController.restorationIdentifier = @"Edit composition";
                 self.replyViewController.delegate = self;
                 UINavigationController *nav = [self.replyViewController enclosingNavigationController];
                 nav.restorationIdentifier = @"Edit composition navigation controller";
                 [self presentViewController:nav animated:YES completion:nil];
             }];
        }]];
    }
    if (!self.thread.closed) {
        [sheet addItem:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeQuotePost action:^{
            [[AwfulHTTPClient client] quoteTextOfPostWithID:post.postID
                                                    andThen:^(NSError *error, NSString *quotedText)
             {
                 if (error) {
                     [AwfulAlertView showWithTitle:@"Could Not Quote Post"
                                             error:error
                                       buttonTitle:@"Alright"];
                     return;
                 }
                 if (self.replyViewController) {
                     UITextView *textView = self.replyViewController.textView;
                     void (^appendString)(NSString *) = ^(NSString *string) {
                         UITextRange *endRange = [textView textRangeFromPosition:textView.endOfDocument
                                                                      toPosition:textView.endOfDocument];
                         [textView replaceRange:endRange withText:string];
                     };
                     while (![textView.text hasSuffix:@"\n\n"]) {
                         appendString(@"\n");
                     }
                     appendString(quotedText);
                 } else {
                     self.replyViewController = [[AwfulReplyViewController alloc] initWithThread:self.thread
                                                                                      quotedText:quotedText];
                     self.replyViewController.delegate = self;
                     self.replyViewController.restorationIdentifier = @"Reply composition";
                 }
                 UINavigationController *nav = [self.replyViewController enclosingNavigationController];
                 nav.restorationIdentifier = @"Reply composition navigation controller";
                 [self presentViewController:nav animated:YES completion:nil];
             }];
        }]];
    }
    [sheet showFromRect:rect inView:self.postsView animated:YES];
}

- (void)showActionsForUser:(AwfulUser *)user fromRect:(CGRect)rect
{
	AwfulIconActionSheet *sheet = [AwfulIconActionSheet new];
	sheet.title = [NSString stringWithFormat:@"%@", user.username];
	[sheet addItem:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeUserProfile action:^{
		[self showProfileWithUser:user];
	}]];
	if (!self.author) {
		[sheet addItem:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeSingleUsersPosts action:^{
            AwfulPostsViewController *postsView = [[AwfulPostsViewController alloc] initWithThread:self.thread author:user];
            postsView.page = 1;
            [self.navigationController pushViewController:postsView animated:YES];
        }]];
	}
	if ([AwfulSettings settings].canSendPrivateMessages &&
        user.canReceivePrivateMessages &&
        ![user.userID isEqual:[AwfulSettings settings].userID]) {
		[sheet addItem:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeSendPrivateMessage action:^{
            AwfulNewPrivateMessageViewController *newPrivateMessageViewController = [[AwfulNewPrivateMessageViewController alloc] initWithRecipient:user];
            [self presentViewController:[newPrivateMessageViewController enclosingNavigationController]
                               animated:YES
                             completion:nil];
        }]];
	}
	[sheet addItem:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeRapSheet action:^{
		[self showRapSheetWithUser:user];
	}]];
    [sheet showFromRect:rect inView:self.postsView animated:YES];
}

- (void)postsView:(AwfulPostsView *)postsView didReceiveLongTapAtPoint:(CGPoint)point
{
    NSURL *url;
    CGRect rect;
    if ((url = [postsView URLOfSpoiledImageForPoint:point])) {
        AwfulImagePreviewViewController *preview = [[AwfulImagePreviewViewController alloc]
                                                    initWithURL:url];
        preview.title = self.title;
        UINavigationController *nav = [preview enclosingNavigationController];
        nav.navigationBar.translucent = YES;
        [self presentViewController:nav animated:YES completion:nil];
    } else if ((url = [postsView URLOfSpoiledLinkForPoint:point rect:&rect])) {
        [self showMenuForLinkToURL:url fromRect:rect];
    } else if ((url = [postsView URLOfSpoiledVideoForPoint:point rect:&rect])) {
        NSURL *safariURL;
        if ([url.host hasSuffix:@"youtube-nocookie.com"]) {
            NSString *youtubeVideoID = url.lastPathComponent;
            safariURL = [NSURL URLWithString:[NSString stringWithFormat:
                                              @"http://www.youtube.com/watch?v=%@", youtubeVideoID]];
        } else if ([url.host hasSuffix:@"player.vimeo.com"]) {
            NSString *vimeoVideoID = url.lastPathComponent;
            safariURL = [NSURL URLWithString:[NSString stringWithFormat:
                                              @"http://vimeo.com/%@", vimeoVideoID]];
        }
        if (!safariURL) return;
        AwfulActionSheet *sheet = [AwfulActionSheet new];
        [sheet addButtonWithTitle:@"Open in Safari" block:^{
            [[UIApplication sharedApplication] openURL:safariURL];
        }];
        [sheet addCancelButtonWithTitle:@"Cancel"];
        [sheet showFromRect:rect inView:self.postsView animated:YES];
    }
}

- (void)showMenuForLinkToURL:(NSURL *)url fromRect:(CGRect)rect
{
    if (![url opensInBrowser]) {
        [[UIApplication sharedApplication] openURL:url];
        return;
    }
    AwfulActionSheet *sheet = [AwfulActionSheet new];
    sheet.title = url.absoluteString;
    [sheet addButtonWithTitle:@"Open" block:^{
        if ([url awfulURL]) {
            [[AwfulAppDelegate instance] openAwfulURL:[url awfulURL]];
        } else {
            [self openURLInBuiltInBrowser:url];
        }
    }];
    [sheet addButtonWithTitle:@"Open in Safari"
                        block:^{ [[UIApplication sharedApplication] openURL:url]; }];
    for (AwfulExternalBrowser *browser in [AwfulExternalBrowser installedBrowsers]) {
        if (![browser canOpenURL:url]) continue;
        [sheet addButtonWithTitle:[NSString stringWithFormat:@"Open in %@", browser.title]
                            block:^{ [browser openURL:url]; }];
    }
    for (AwfulReadLaterService *service in [AwfulReadLaterService availableServices]) {
        [sheet addButtonWithTitle:service.callToAction block:^{
            [service saveURL:url];
        }];
    }
    [sheet addButtonWithTitle:@"Copy URL" block:^{
        [UIPasteboard generalPasteboard].items = @[ @{
            (id)kUTTypeURL: url,
            (id)kUTTypePlainText: url.absoluteString,
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
    [self.postsView.scrollView.pullToRefreshView stopAnimating];
    [self updateUserInterface];
}

#pragma mark - AwfulJumpToPageControllerDelegate

- (void)jumpToPageController:(AwfulJumpToPageController *)jump didSelectPage:(AwfulThreadPage)page
{
    if (page != AwfulThreadPageNone) {
        if (self.author && page == AwfulThreadPageLast) {
            page = [self.thread numberOfPagesForSingleUser:self.author];
        }
        self.page = page;
    }
    [self.jumpToPagePopover dismissPopoverAnimated:NO];
    self.jumpToPagePopover = nil;
}

#pragma mark - WYPopoverControllerDelegate

- (void)popoverControllerDidDismiss:(WYPopoverController *)popoverController
{
    self.jumpToPagePopover = nil;
    self.pageSettingsPopover = nil;
}

#pragma mark - AwfulComposeTextViewControllerDelegate

- (void)composeTextViewController:(AwfulComposeTextViewController *)composeTextViewController
didFinishWithSuccessfulSubmission:(BOOL)success
{
    if ([composeTextViewController isEqual:self.replyViewController]) {
        [self replyViewController:(AwfulReplyViewController *)composeTextViewController didFinishWithSuccessfulSubmission:success];
    } else {
        [self newPrivateMessageViewController:(AwfulNewPrivateMessageViewController *)composeTextViewController
            didFinishWithSuccessfulSubmission:success];
    }
}

- (void)replyViewController:(AwfulReplyViewController *)replyViewController didFinishWithSuccessfulSubmission:(BOOL)success
{
    [self dismissViewControllerAnimated:YES completion:^{
        if (!success) return;
        if (replyViewController.thread) {
            self.page = AwfulThreadPageNextUnread;
        } else {
            if (self.author) {
                self.page = replyViewController.post.singleUserPage;
            } else {
                self.page = replyViewController.post.page;
            }
            self.topPost = replyViewController.post;
        }
        self.replyViewController = nil;
    }];
}

- (void)newPrivateMessageViewController:(AwfulNewPrivateMessageViewController *)newPrivateMessageViewController
      didFinishWithSuccessfulSubmission:(BOOL)success
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

#pragma mark - AwfulPageSettingsViewControllerDelegate

- (void)pageSettingsSelectedThemeDidChange:(AwfulPageSettingsViewController *)pageSettings
{
    AwfulTheme *theme = pageSettings.selectedTheme;
    if (theme.forumSpecific) {
        [[AwfulSettings settings] setThemeName:theme.name forForumID:self.thread.forum.forumID];
    } else {
        [[AwfulSettings settings] setThemeName:nil forForumID:self.thread.forum.forumID];
        [AwfulSettings settings].darkTheme = ![theme isEqual:[AwfulThemeLoader sharedLoader].defaultTheme];
    }
	
	[self themeDidChange];
}

#pragma mark - State Preservation and Restoration

+ (UIViewController *)viewControllerWithRestorationIdentifierPath:(NSArray *)identifierComponents coder:(NSCoder *)coder
{
    AwfulThread *thread = [AwfulThread firstOrNewThreadWithThreadID:[coder decodeObjectForKey:ThreadIDKey]
                                             inManagedObjectContext:AwfulAppDelegate.instance.managedObjectContext];
    NSString *authorUserID = [coder decodeObjectForKey:AuthorUserIDKey];
    AwfulUser *author;
    if (authorUserID.length > 0) {
        author = [AwfulUser firstOrNewUserWithUserID:authorUserID
                                            username:nil
                              inManagedObjectContext:AwfulAppDelegate.instance.managedObjectContext];
    }
    AwfulPostsViewController *postsView = [[AwfulPostsViewController alloc] initWithThread:thread author:author];
    postsView.restorationIdentifier = identifierComponents.lastObject;
    return postsView;
}

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super encodeRestorableStateWithCoder:coder];
    [coder encodeObject:self.thread.threadID forKey:ThreadIDKey];
    [coder encodeInteger:self.page forKey:PageKey];
    [coder encodeObject:self.author.userID forKey:AuthorUserIDKey];
    [coder encodeInteger:self.hiddenPosts forKey:HiddenPostsKey];
    [coder encodeObject:self.replyViewController forKey:ReplyViewControllerKey];
    [coder encodeObject:self.advertisementHTML forKey:AdvertisementHTMLKey];
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super decodeRestorableStateWithCoder:coder];
    self.replyViewController = [coder decodeObjectForKey:ReplyViewControllerKey];
    self.replyViewController.delegate = self;
    [self loadCachedPostsFromPage:[coder decodeIntegerForKey:PageKey]];
    self.hiddenPosts = [coder decodeIntegerForKey:HiddenPostsKey];
    self.advertisementHTML = [coder decodeObjectForKey:AdvertisementHTMLKey];
    [self.postsView reloadData];
}

static NSString * const ThreadIDKey = @"AwfulThreadID";
static NSString * const PageKey = @"AwfulCurrentPage";
static NSString * const AuthorUserIDKey = @"AwfulAuthorUserID";
static NSString * const HiddenPostsKey = @"AwfulHiddenPosts";
static NSString * const ReplyViewControllerKey = @"AwfulReplyViewController";
static NSString * const AdvertisementHTMLKey = @"AwfulAdvertisementHTML";

@end
