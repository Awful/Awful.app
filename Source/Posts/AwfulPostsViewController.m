//  AwfulPostsViewController.m
//
//  Copyright 2010 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPostsViewController.h"
#import "AwfulActionSheet.h"
#import "AwfulActionViewController.h"
#import "AwfulAlertView.h"
#import "AwfulAppDelegate.h"
#import "AwfulBrowserViewController.h"
#import "AwfulDateFormatters.h"
#import "AwfulExternalBrowser.h"
#import "AwfulForumsClient.h"
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
#import <MRProgress/MRProgressOverlayView.h>
#import <SVPullToRefresh/SVPullToRefresh.h>

@interface AwfulPostsViewController () <AwfulPostsViewDelegate, NSFetchedResultsControllerDelegate, AwfulComposeTextViewControllerDelegate, UIScrollViewDelegate, UIViewControllerRestoration>

@property (nonatomic) NSFetchedResultsController *fetchedResultsController;

@property (weak, nonatomic) NSOperation *networkOperation;

@property (nonatomic) AwfulPageTopBar *topBar;
@property (strong, nonatomic) AwfulPostsView *postsView;
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

@property (nonatomic) NSMutableArray *cachedUpdatesWhileScrolling;

@property (strong, nonatomic) AwfulReplyViewController *replyViewController;
@property (strong, nonatomic) AwfulNewPrivateMessageViewController *messageViewController;

@end

@implementation AwfulPostsViewController

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopObservingScrollViewContentSize];
    self.postsView.scrollView.delegate = nil;
    self.fetchedResultsController.delegate = nil;
}

- (id)initWithThread:(AwfulThread *)thread author:(AwfulUser *)author
{
    self = [super initWithNibName:nil bundle:nil];
    if (!self) return nil;
    
    _thread = thread;
    _author = author;
    self.restorationClass = self.class;
    
    self.navigationItem.rightBarButtonItem = self.composeItem;
    self.navigationItem.backBarButtonItem = [UIBarButtonItem awful_emptyBackBarButtonItem];
    
    const CGFloat spacerWidth = 12;
    self.toolbarItems = @[ self.settingsItem,
                           [UIBarButtonItem awful_flexibleSpace],
                           self.backItem,
                           [UIBarButtonItem awful_fixedSpace:spacerWidth],
                           self.currentPageItem,
                           [UIBarButtonItem awful_fixedSpace:spacerWidth],
                           self.forwardItem,
                           [UIBarButtonItem awful_flexibleSpace],
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

- (AwfulTheme *)theme
{
    AwfulForum *forum = self.thread.forum;
    return forum.forumID.length > 0 ? [AwfulTheme currentThemeForForum:self.thread.forum] : [AwfulTheme currentTheme];
}

- (UIBarButtonItem *)composeItem
{
    if (_composeItem) return _composeItem;
    _composeItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCompose target:self action:@selector(didTapCompose)];
    return _composeItem;
}

- (void)didTapCompose
{
    if (!self.replyViewController) {
        self.replyViewController = [[AwfulReplyViewController alloc] initWithThread:self.thread quotedText:nil];
        self.replyViewController.delegate = self;
        self.replyViewController.restorationIdentifier = @"Reply composition";
    }
    [self presentViewController:[self.replyViewController enclosingNavigationController] animated:YES completion:nil];
}

- (UIBarButtonItem *)settingsItem
{
    if (_settingsItem) return _settingsItem;
    _settingsItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"page-settings"]
                                                     style:UIBarButtonItemStylePlain
                                                    target:self
                                                    action:@selector(didTapSettingsItem:)];
    return _settingsItem;
}

- (void)didTapSettingsItem:(UIBarButtonItem *)sender
{
    AwfulPageSettingsViewController *settings = [[AwfulPageSettingsViewController alloc] initWithForum:self.thread.forum];
    settings.selectedTheme = self.theme;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [settings presentInPopoverFromBarButtonItem:sender];
    } else {
        UIToolbar *toolbar = self.navigationController.toolbar;
        [settings presentFromView:self.view highlightingRegionReturnedByBlock:^(UIView *view) {
            return [view convertRect:toolbar.bounds fromView:toolbar];
        }];
    }
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
                                                       action:@selector(showJumpToPageSheet:)];
    _currentPageItem.possibleTitles = [NSSet setWithObject:@"2345 / 2345"];
    return _currentPageItem;
}

- (void)showJumpToPageSheet:(UIBarButtonItem *)sender
{
    if (self.loadingView) return;
    AwfulJumpToPageController *jump = [[AwfulJumpToPageController alloc] initWithPostsViewController:self];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [jump presentInPopoverFromBarButtonItem:sender];
    } else {
        UIToolbar *toolbar = self.navigationController.toolbar;
        [jump presentFromView:self.view highlightingRegionReturnedByBlock:^(UIView *view) {
            return [view convertRect:toolbar.bounds fromView:toolbar];
        }];
    }
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
    AwfulActionViewController *sheet = [AwfulActionViewController new];
    sheet.title = self.title;
    AwfulIconActionItem *copyURL = [AwfulIconActionItem itemWithType:AwfulIconActionItemTypeCopyURL action:^{
        NSURLComponents *components = [NSURLComponents componentsWithString:@"http://forums.somethingawful.com/showthread.php"];
        NSMutableArray *queryParts = [NSMutableArray new];
        [queryParts addObject:[NSString stringWithFormat:@"threadid=%@", self.thread.threadID]];
        [queryParts addObject:@"perpage=40"];
        if (self.page > 1) {
            [queryParts addObject:[NSString stringWithFormat:@"pagenumber=%@", @(self.page)]];
        }
        components.query = [queryParts componentsJoinedByString:@"&"];
        NSURL *URL = components.URL;
        [AwfulSettings settings].lastOfferedPasteboardURL = URL.absoluteString;
        [UIPasteboard generalPasteboard].items = @[ @{ (id)kUTTypeURL: URL,
                                                       (id)kUTTypePlainText: URL.absoluteString }];
    }];
    copyURL.title = @"Copy Thread URL";
    [sheet addItem:copyURL];
    [sheet addItem:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeVote action:^{
        AwfulActionSheet *vote = [AwfulActionSheet new];
        for (int i = 5; i >= 1; i--) {
            [vote addButtonWithTitle:[@(i) stringValue] block:^{
                MRProgressOverlayView *overlay = [MRProgressOverlayView showOverlayAddedTo:self.view
                                                                                     title:[NSString stringWithFormat:@"Voting %i", i]
                                                                                      mode:MRProgressOverlayViewModeIndeterminate
                                                                                  animated:YES];
                overlay.tintColor = self.theme[@"tintColor"];
                [[AwfulForumsClient client] rateThread:self.thread :i andThen:^(NSError *error) {
                    if (error) {
                        [overlay dismiss:NO];
                        [AwfulAlertView showWithTitle:@"Vote Failed" error:error buttonTitle:@"OK"];
                    } else {
                        overlay.mode = MRProgressOverlayViewModeCheckmark;
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                            [overlay dismiss:YES];
                        });
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
        [[AwfulForumsClient client] setThread:self.thread
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
                 MRProgressOverlayView *overlay = [MRProgressOverlayView showOverlayAddedTo:self.view
                                                                                      title:status
                                                                                       mode:MRProgressOverlayViewModeCheckmark
                                                                                   animated:YES];
//                 overlay.tintColor = self.theme[@"tintColor"];
                 dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                     [overlay dismiss:YES];
                 });
             }
         }];
    }]];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [sheet presentInPopoverFromBarButtonItem:barButtonItem];
    } else {
        UINavigationController *navigationController = self.navigationController;
        [sheet presentFromView:self.view highlightingRegionReturnedByBlock:^(UIView *view) {
            UIToolbar *toolbar = navigationController.toolbar;
            return [view convertRect:toolbar.bounds fromView:toolbar];
        }];
    }
}

- (void)settingsDidChange:(NSNotification *)note
{
    if (![self isViewLoaded]) return;
    
    NSString *changedSetting = note.userInfo[AwfulSettingsDidChangeSettingKey];
    if ([changedSetting isEqualToString:AwfulSettingsKeys.showAvatars] || [changedSetting isEqualToString:AwfulSettingsKeys.username] || [changedSetting isEqualToString:AwfulSettingsKeys.fontScale]) {
        [self configurePostsViewSettings];
    } else if ([changedSetting isEqualToString:AwfulSettingsKeys.showImages]) {
        if ([AwfulSettings settings].showImages) {
            [self.postsView loadLinkifiedImages];
        }
    }
}

- (void)themeDidChange
{
    [super themeDidChange];
    self.topBar.backgroundColor = self.theme[@"postsTopBarBackgroundColor"];
    void (^configureButton)(UIButton *) = ^(UIButton *button){
        [button setTitleColor:self.theme[@"postsTopBarTextColor"] forState:UIControlStateNormal];
        [button setTitleColor:[UIColor lightGrayColor] forState:UIControlStateDisabled];
        button.backgroundColor = self.theme[@"postsTopBarBackgroundColor"];
    };
    configureButton(self.topBar.goToForumButton);
    configureButton(self.topBar.loadReadPostsButton);
    configureButton(self.topBar.scrollToBottomButton);
    [self configurePostsViewSettings];
    [self.replyViewController themeDidChange];
}

- (void)setThread:(AwfulThread *)thread
{
    if ([_thread isEqual:thread]) return;
    [self willChangeValueForKey:@"thread"];
    _thread = thread;
    [self didChangeValueForKey:@"thread"];
    [self updateFetchedResultsController];
    [self updateUserInterface];
    self.postsView.stylesheet = self.theme[@"postsViewCSS"];
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
        self.loadingView = [AwfulLoadingView loadingViewForTheme:self.theme];
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
    AwfulTheme *theme = self.theme;
	self.postsView.backgroundColor = theme[@"backgroundColor"];
    self.view.backgroundColor = theme[@"backgroundColor"];
	
    self.postsView.showAvatars = [AwfulSettings settings].showAvatars;
    self.postsView.fontScale = [AwfulSettings settings].fontScale;
    self.postsView.highlightMentionUsername = [AwfulSettings settings].username;
    self.postsView.stylesheet = theme[@"postsViewCSS"];
	self.postsView.scrollView.indicatorStyle = theme.scrollIndicatorStyle;
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
            if ([AwfulForumsClient client].reachable || ![error.domain isEqualToString:NSURLErrorDomain]) {
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
    if (self.posts.count == 0) {
        [self refreshCurrentPage];
    } else if (self.topPostAfterLoad) {
        self.topPost = self.topPostAfterLoad;
        self.topPostAfterLoad = nil;
    }
    [self updateUserInterface];
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
    id op = [[AwfulForumsClient client] listPostsInThread:self.thread
                                              writtenBy:self.author
                                                 onPage:page
                                                andThen:^(NSError *error, NSArray *posts, NSUInteger firstUnreadPost, NSString *advertisementHTML)
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
             }];
    self.networkOperation = op;
}

- (void)setTopPost:(AwfulPost *)topPost
{
    if (![self isViewLoaded] || self.loadingView) {
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
    [self presentViewController:[profile enclosingNavigationController] animated:YES completion:nil];
}

- (void)showRapSheetWithUser:(AwfulUser *)user
{
    AwfulRapSheetViewController *rapSheet = [[AwfulRapSheetViewController alloc] initWithUser:user];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self presentViewController:[rapSheet enclosingNavigationController] animated:YES completion:nil];
    } else {
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
    NSURL *baseURL = [AwfulForumsClient client].baseURL;
    self.postsView = [[AwfulPostsView alloc] initWithFrame:CGRectZero baseURL:baseURL];
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
    
    NSArray *buttons = @[ self.topBar.goToForumButton, self.topBar.loadReadPostsButton, self.topBar.scrollToBottomButton ];
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
    __weak __typeof__(self) weakSelf = self;
    [self.postsView.scrollView addPullToRefreshWithActionHandler:^{
        __typeof__(self) self = weakSelf;
        [self loadNextPageOrRefresh];
    } position:SVPullToRefreshPositionBottom];
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
                                   context:KVOContext];
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
    if (context == KVOContext) {
        if ([keyPath isEqualToString:@"contentSize"]) {
            CGSize oldSize = [change[NSKeyValueChangeOldKey] CGSizeValue];
            CGSize newSize = [change[NSKeyValueChangeNewKey] CGSizeValue];
            CGPoint contentOffset = [object contentOffset];
            contentOffset.y += newSize.height - oldSize.height;
            [object setContentOffset:contentOffset];
            [self stopObservingScrollViewContentSize];
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

static void *KVOContext = &KVOContext;

- (void)stopObservingScrollViewContentSize
{
    if (_observingScrollViewSize && [self isViewLoaded]) {
        [self.postsView.scrollView removeObserver:self
                                       forKeyPath:@"contentSize"
                                          context:KVOContext];
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
    NSString *html = [self.postTemplate renderObject:[[AwfulPostViewModel alloc] initWithPost:post] error:&error];
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

- (void)postsView:(AwfulPostsView *)postsView willFollowLinkToURL:(NSURL *)URL
{
    if ([URL awfulURL]) {
        if ([URL.fragment isEqualToString:@"awful-ignored"]) {
            NSString *postID = URL.awfulURL.lastPathComponent;
            NSUInteger index = [[self.posts valueForKey:@"postID"] indexOfObject:postID];
            if (index != NSNotFound) {
                [self readIgnoredPostAtIndex:index];
            }
        } else {
            [[AwfulAppDelegate instance] openAwfulURL:[URL awfulURL]];
        }
    } else if ([URL opensInBrowser]) {
        [AwfulBrowserViewController presentBrowserForURL:URL fromViewController:self];
    } else {
        [[UIApplication sharedApplication] openURL:URL];
    }
}

- (void)readIgnoredPostAtIndex:(NSUInteger)index
{
    AwfulPost *post = self.posts[index];
    AwfulThreadPage page = self.page;
    __weak __typeof__(self) weakSelf = self;
    [[AwfulForumsClient client] readIgnoredPost:post andThen:^(NSError *error) {
        __typeof__(self) self = weakSelf;
        if (error) {
            [AwfulAlertView showWithTitle:@"Network Error" error:error buttonTitle:@"OK"];
        } else if (self.page == page) {
            [self.postsView reloadPostAtIndex:index];
        }
    }];
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
        [self showActionsForAuthorOfPost:post fromRect:rect];
    }
}

- (void)showActionsForPost:(AwfulPost *)post fromRect:(CGRect)rect
{
    NSString *possessiveUsername = [NSString stringWithFormat:@"%@'s", post.author.username];
    if ([post.author.username isEqualToString:[AwfulSettings settings].username]) {
        possessiveUsername = @"Your";
    }
    AwfulActionViewController *sheet = [AwfulActionViewController new];
    sheet.title = [NSString stringWithFormat:@"%@ Post", possessiveUsername];
    [sheet addItem:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeCopyURL action:^{
        NSURLComponents *components = [NSURLComponents componentsWithString:@"http://forums.somethingawful.com/showthread.php"];
        NSMutableArray *queryParts = [NSMutableArray new];
        [queryParts addObject:[NSString stringWithFormat:@"threadid=%@", self.thread.threadID]];
        [queryParts addObject:@"perpage=40"];
        if (self.page > 1) {
            [queryParts addObject:[NSString stringWithFormat:@"pagenumber=%@", @(self.page)]];
        }
        components.query = [queryParts componentsJoinedByString:@"&"];
        components.fragment = [NSString stringWithFormat:@"post%@", post.postID];
        NSURL *URL = components.URL;
        [AwfulSettings settings].lastOfferedPasteboardURL = URL.absoluteString;
        [UIPasteboard generalPasteboard].items = @[ @{ (id)kUTTypeURL: URL,
                                                       (id)kUTTypePlainText: URL.absoluteString }];
    }]];
    if (!self.author) {
        [sheet addItem:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeMarkReadUpToHere action:^{
            [[AwfulForumsClient client] markThreadReadUpToPost:post andThen:^(NSError *error) {
                if (error) {
                    [AwfulAlertView showWithTitle:@"Could Not Mark Read" error:error buttonTitle:@"Alright"];
                } else {
                    post.thread.seenPosts = post.threadIndex;
                    [self.postsView setLastReadPostID:post.postID];
                }
            }];
        }]];
    }
    if (post.editable) {
        [sheet addItem:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeEditPost action:^{
            [[AwfulForumsClient client] findBBcodeContentsWithPost:post andThen:^(NSError *error, NSString *text) {
                if (error) {
                    [AwfulAlertView showWithTitle:@"Could Not Edit Post" error:error buttonTitle:@"OK"];
                    return;
                }
                self.replyViewController = [[AwfulReplyViewController alloc] initWithPost:post originalText:text];
                self.replyViewController.restorationIdentifier = @"Edit composition";
                self.replyViewController.delegate = self;
                [self presentViewController:[self.replyViewController enclosingNavigationController] animated:YES completion:nil];
            }];
        }]];
    }
    if (!self.thread.closed) {
        [sheet addItem:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeQuotePost action:^{
            [[AwfulForumsClient client] quoteBBcodeContentsWithPost:post andThen:^(NSError *error, NSString *quotedText) {
                if (error) {
                    [AwfulAlertView showWithTitle:@"Could Not Quote Post" error:error buttonTitle:@"OK"];
                    return;
                }
                if (self.replyViewController) {
                    UITextView *textView = self.replyViewController.textView;
                    void (^appendString)(NSString *) = ^(NSString *string) {
                        UITextRange *endRange = [textView textRangeFromPosition:textView.endOfDocument toPosition:textView.endOfDocument];
                        [textView replaceRange:endRange withText:string];
                    };
                    if ([textView comparePosition:textView.beginningOfDocument toPosition:textView.endOfDocument] != NSOrderedSame) {
                        while (![textView.text hasSuffix:@"\n\n"]) {
                            appendString(@"\n");
                        }
                    }
                    appendString(quotedText);
                } else {
                    self.replyViewController = [[AwfulReplyViewController alloc] initWithThread:self.thread quotedText:quotedText];
                    self.replyViewController.delegate = self;
                    self.replyViewController.restorationIdentifier = @"Reply composition";
                }
                [self presentViewController:[self.replyViewController enclosingNavigationController] animated:YES completion:nil];
            }];
        }]];
    }
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [sheet presentInPopoverFromView:self.postsView pointingToRegionReturnedByBlock:^(UIView *view) {
            return [self.postsView rectOfActionButtonForPostWithID:post.postID];
        }];
    } else {
        [sheet presentFromView:self.postsView highlightingRegionReturnedByBlock:^(UIView *view) {
            CGRect rect = [self.postsView rectOfFooterForPostWithID:post.postID];
            rect.origin.x = 0;
            rect.size.width = CGRectGetWidth(self.postsView.bounds);
            return rect;
        }];
    }
}

- (void)showActionsForAuthorOfPost:(AwfulPost *)post fromRect:(CGRect)rect
{
    AwfulUser *user = post.author;
	AwfulActionViewController *sheet = [AwfulActionViewController new];
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
            self.messageViewController = [[AwfulNewPrivateMessageViewController alloc] initWithRecipient:user];
            self.messageViewController.delegate = self;
            self.messageViewController.restorationIdentifier = @"New PM from posts view";
            [self presentViewController:[self.messageViewController enclosingNavigationController] animated:YES completion:nil];
        }]];
	}
	[sheet addItem:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeRapSheet action:^{
		[self showRapSheetWithUser:user];
	}]];
    
    AwfulSemiModalRectInViewBlock headerRectBlock = ^(UIView *view) {
        CGRect rect = [self.postsView rectOfHeaderForPostWithID:post.postID];
        rect.origin.x = 0;
        rect.size.width = CGRectGetMaxX(self.postsView.bounds);
        return rect;
    };
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [sheet presentInPopoverFromView:self.postsView pointingToRegionReturnedByBlock:headerRectBlock];
    } else {
        [sheet presentFromView:self.postsView highlightingRegionReturnedByBlock:headerRectBlock];
    }
}

- (void)postsView:(AwfulPostsView *)postsView didReceiveLongTapAtPoint:(CGPoint)point
{
    NSURL *URL;
    CGRect rect;
    if ((URL = [postsView URLOfSpoiledImageForPoint:point])) {
        URL = [NSURL URLWithString:URL.absoluteString relativeToURL:[AwfulForumsClient client].baseURL];
        AwfulImagePreviewViewController *preview = [[AwfulImagePreviewViewController alloc] initWithURL:URL];
        preview.title = self.title;
        UINavigationController *nav = [preview enclosingNavigationController];
        nav.navigationBar.translucent = YES;
        [self presentViewController:nav animated:YES completion:nil];
    } else if ((URL = [postsView URLOfSpoiledLinkForPoint:point rect:&rect])) {
        URL = [NSURL URLWithString:URL.absoluteString relativeToURL:[AwfulForumsClient client].baseURL];
        [self showMenuForLinkToURL:URL fromRect:rect];
    } else if ((URL = [postsView URLOfSpoiledVideoForPoint:point rect:&rect])) {
        URL = [NSURL URLWithString:URL.absoluteString relativeToURL:[AwfulForumsClient client].baseURL];
        NSURL *safariURL;
        if ([URL.host hasSuffix:@"youtube-nocookie.com"]) {
            NSString *youtubeVideoID = URL.lastPathComponent;
            safariURL = [NSURL URLWithString:[NSString stringWithFormat:
                                              @"http://www.youtube.com/watch?v=%@", youtubeVideoID]];
        } else if ([URL.host hasSuffix:@"player.vimeo.com"]) {
            NSString *vimeoVideoID = URL.lastPathComponent;
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

- (void)showMenuForLinkToURL:(NSURL *)URL fromRect:(CGRect)rect
{
    if (![URL opensInBrowser]) {
        [[UIApplication sharedApplication] openURL:URL];
        return;
    }
    AwfulActionSheet *sheet = [AwfulActionSheet new];
    sheet.title = URL.absoluteString;
    [sheet addButtonWithTitle:@"Open" block:^{
        if ([URL awfulURL]) {
            [[AwfulAppDelegate instance] openAwfulURL:[URL awfulURL]];
        } else {
            [AwfulBrowserViewController presentBrowserForURL:URL fromViewController:self];
        }
    }];
    [sheet addButtonWithTitle:@"Open in Safari"
                        block:^{ [[UIApplication sharedApplication] openURL:URL]; }];
    for (AwfulExternalBrowser *browser in [AwfulExternalBrowser installedBrowsers]) {
        if (![browser canOpenURL:URL]) continue;
        [sheet addButtonWithTitle:[NSString stringWithFormat:@"Open in %@", browser.title]
                            block:^{ [browser openURL:URL]; }];
    }
    for (AwfulReadLaterService *service in [AwfulReadLaterService availableServices]) {
        [sheet addButtonWithTitle:service.callToAction block:^{
            [service saveURL:URL];
        }];
    }
    [sheet addButtonWithTitle:@"Copy URL" block:^{
        [UIPasteboard generalPasteboard].items = @[ @{
            (id)kUTTypeURL: URL,
            (id)kUTTypePlainText: URL.absoluteString,
        } ];
        [AwfulSettings settings].lastOfferedPasteboardURL = URL.absoluteString;
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

#pragma mark - AwfulComposeTextViewControllerDelegate

- (void)composeTextViewController:(AwfulComposeTextViewController *)composeTextViewController
didFinishWithSuccessfulSubmission:(BOOL)success
                  shouldKeepDraft:(BOOL)keepDraft
{
    if ([composeTextViewController isEqual:self.replyViewController]) {
        [self replyViewController:(AwfulReplyViewController *)composeTextViewController
didFinishWithSuccessfulSubmission:success
                  shouldKeepDraft:keepDraft];
    } else {
        [self newPrivateMessageViewController:(AwfulNewPrivateMessageViewController *)composeTextViewController
            didFinishWithSuccessfulSubmission:success
                              shouldKeepDraft:keepDraft];
    }
}

- (void)replyViewController:(AwfulReplyViewController *)replyViewController
didFinishWithSuccessfulSubmission:(BOOL)success
            shouldKeepDraft:(BOOL)keepDraft
{
    [self dismissViewControllerAnimated:YES completion:^{
        if (success) {
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
        }
        if (!keepDraft) {
            self.replyViewController = nil;
        }
    }];
}

- (void)newPrivateMessageViewController:(AwfulNewPrivateMessageViewController *)newPrivateMessageViewController
      didFinishWithSuccessfulSubmission:(BOOL)success
                        shouldKeepDraft:(BOOL)keepDraft
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
    [coder encodeObject:self.messageViewController forKey:MessageViewControllerKey];
    [coder encodeObject:self.advertisementHTML forKey:AdvertisementHTMLKey];
    [coder encodeFloat:self.postsView.scrolledFractionOfContent forKey:ScrolledFractionOfContentKey];
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super decodeRestorableStateWithCoder:coder];
    self.replyViewController = [coder decodeObjectForKey:ReplyViewControllerKey];
    self.replyViewController.delegate = self;
    self.messageViewController = [coder decodeObjectForKey:MessageViewControllerKey];
    self.messageViewController.delegate = self;
    [self loadCachedPostsFromPage:[coder decodeIntegerForKey:PageKey]];
    self.hiddenPosts = [coder decodeIntegerForKey:HiddenPostsKey];
    self.advertisementHTML = [coder decodeObjectForKey:AdvertisementHTMLKey];
    [self.postsView reloadData];
    [self.postsView scrollToFractionOfContent:[coder decodeFloatForKey:ScrolledFractionOfContentKey]];
}

static NSString * const ThreadIDKey = @"AwfulThreadID";
static NSString * const PageKey = @"AwfulCurrentPage";
static NSString * const AuthorUserIDKey = @"AwfulAuthorUserID";
static NSString * const HiddenPostsKey = @"AwfulHiddenPosts";
static NSString * const ReplyViewControllerKey = @"AwfulReplyViewController";
static NSString * const MessageViewControllerKey = @"AwfulMessageViewController";
static NSString * const AdvertisementHTMLKey = @"AwfulAdvertisementHTML";
static NSString * const ScrolledFractionOfContentKey = @"AwfulScrolledFractionOfContentSize";

@end
