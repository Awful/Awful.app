//  PostsPageViewController.m
//
//  Copyright 2010 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "PostsPageViewController.h"
@import ARChromeActivity;
#import "AwfulFrameworkCategories.h"
#import "AwfulJavaScript.h"
#import "AwfulLoadingView.h"
#import "AwfulPostsView.h"
#import "AwfulPostsViewExternalStylesheetLoader.h"
#import "AwfulWebViewNetworkActivityIndicatorManager.h"
@import GRMustache;
@import MRProgress;
#import "PostComposeViewController.h"
#import "PostViewModel.h"
@import SVPullToRefresh;
@import TUSafariActivity;
@import WebViewJavascriptBridge;
#import "Awful-Swift.h"

@interface PostsPageViewController () <AwfulComposeTextViewControllerDelegate, UIGestureRecognizerDelegate, UIViewControllerRestoration, UIWebViewDelegate>

@property (assign, nonatomic) NSInteger page;

@property (weak, nonatomic) NSOperation *networkOperation;

@property (readonly, strong, nonatomic) AwfulPostsView *postsView;
@property (readonly, strong, nonatomic) UIWebView *webView;

@property (nonatomic) UIBarButtonItem *composeItem;

@property (strong, nonatomic) UIBarButtonItem *settingsItem;
@property (strong, nonatomic) UIBarButtonItem *backItem;
@property (strong, nonatomic) UIBarButtonItem *currentPageItem;
@property (strong, nonatomic) UIBarButtonItem *forwardItem;
@property (strong, nonatomic) UIBarButtonItem *actionsItem;

@property (nonatomic) NSInteger hiddenPosts;
@property (copy, nonatomic) NSString *advertisementHTML;
@property (nonatomic) AwfulLoadingView *loadingView;

@property (strong, nonatomic) ReplyWorkspace *replyWorkspace;
@property (strong, nonatomic) MessageComposeViewController *messageViewController;

@property (copy, nonatomic) NSArray *posts;

@end

@implementation PostsPageViewController
{
    AwfulWebViewNetworkActivityIndicatorManager *_webViewNetworkActivityIndicatorManager;
    WebViewJavascriptBridge *_webViewJavaScriptBridge;
    BOOL _webViewDidLoadOnce;
    NSString *_jumpToPostIDAfterLoading;
    CGFloat _scrollToFractionAfterLoading;
    BOOL _restoringState;
    BOOL _noSeen;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)initWithThread:(Thread *)thread author:(User *)author
{
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _thread = thread;
        _author = author;
        self.restorationClass = self.class;
        
        self.navigationItem.rightBarButtonItem = self.composeItem;
        
        self.hidesBottomBarWhenPushed = YES;
        
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
    }
    return self;
}

- (instancetype)initWithThread:(Thread *)thread noSeen:(bool)noSeen
{
    _noSeen = noSeen;
    return [self initWithThread:thread author:nil];
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    NSAssert(nil, @"Use -initWithThread:…");
    return [self initWithThread:nil author:nil];
}

// TODO: Not sure why these warnings appear here.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

- (instancetype)initWithCoder:(NSCoder *)coder
{
    NSAssert(nil, @"NSCoding is not supported");
    return [super initWithCoder:coder];
}

#pragma clang diagnostic pop

- (NSInteger)numberOfPages
{
    if (self.author) {
        return [self.thread filteredNumberOfPagesForAuthor:self.author];
    } else {
        return self.thread.numberOfPages;
    }
}

- (void)loadPage:(NSInteger)page updatingCache:(BOOL)updateCache
{
    [self.networkOperation cancel];
    self.networkOperation = nil;
    
    // SA: When filtering the thread by a single user, the "goto=lastpost" redirect ignores the user filter, so we'll do our best to guess.
    if (page == AwfulThreadPageLast && self.author) {
        page = [self.thread filteredNumberOfPagesForAuthor:self.author] ?: 1;
    }
    
    BOOL reloadingSamePage = page == self.page;
    self.page = page;
    
    if (self.posts.count == 0 || !reloadingSamePage) {
        [self.postsView.webView.scrollView.pullToRefreshView stopAnimating];
        [self updateUserInterface];
        if (!_restoringState) {
            self.hiddenPosts = 0;
        }
        [self refetchPosts];
        if (self.posts.count > 0) {
            [self renderPosts];
        }
    }
    
    BOOL renderedCachedPosts = self.posts.count > 0;
    
    [self updateUserInterface];
    
    [self configureUserActivityIfPossible];
    
    if (!updateCache) {
        [self clearLoadingMessage];
        return;
    }
    
    __weak __typeof__(self) weakSelf = self;
    self.networkOperation = [[AwfulForumsClient client] listPostsInThread:self.thread
                                                                writtenBy:self.author
                                                                   onPage:self.page
                                                                   noSeen:_noSeen
                                                                  andThen:^(NSError *error, NSArray *posts, NSUInteger firstUnreadPost, NSString *advertisementHTML)
    {
        __typeof__(self) self = weakSelf;
        
        // We can get out-of-sync here as there's no cancelling the overall scraping operation. Make sure we've got the right page.
        if (page != self.page) return;
        
        if (error) {
            [self clearLoadingMessage];
            if (error.code == AwfulErrorCodes.archivesRequired) {
                [self presentViewController:[UIAlertController alertWithTitle:@"Archives Required" error:error] animated:YES completion:nil];
            } else {
                BOOL offlineMode = ![AwfulForumsClient client].reachable && [error.domain isEqualToString:NSURLErrorDomain];
                if (self.posts.count == 0 || !offlineMode) {
                    [self presentViewController:[UIAlertController alertWithTitle:@"Could Not Load Page" error:error] animated:YES completion:nil];
                }
            }
        }
        
        if (posts.count > 0) {
            self.posts = posts;
            Post *anyPost = posts.lastObject;
            if (self.author) {
                self.page = anyPost.singleUserPage;
            } else {
                self.page = anyPost.page;
            }
        }
        
        if (posts.count == 0 && page < 0) {
            self.currentPageItem.title = [NSString stringWithFormat:@"Page ? of %@", self.numberOfPages > 0 ? @(self.numberOfPages) : @"?"];
        }
        
        if (error) return;
        
        [self configureUserActivityIfPossible];
        
        if (self.hiddenPosts == 0 && firstUnreadPost != NSNotFound) {
            self.hiddenPosts = firstUnreadPost;
        }
        
        if (reloadingSamePage || renderedCachedPosts) {
            _scrollToFractionAfterLoading = self.webView.awful_fractionalContentOffset;
        }
        
        [self renderPosts];
        
        [self updateUserInterface];
        
        Post *lastPost = self.posts.lastObject;
        if(!_noSeen)
        {
            if (self.thread.seenPosts < lastPost.threadIndex) {
                self.thread.seenPosts = lastPost.threadIndex;
            }
        }
        // noSeen should only be respected for the first initial load (Ex. The Peek View Controller).
        // after that, it will start marking all posts as seen.
        _noSeen = NO;
        [self.postsView.webView.scrollView.pullToRefreshView stopAnimating];
    }];
}

- (void)scrollPostToVisible:(Post *)topPost
{
    NSUInteger i = [self.posts indexOfObject:topPost];
    if (self.loadingView || !_webViewDidLoadOnce || i == NSNotFound) {
        _jumpToPostIDAfterLoading = topPost.postID;
    } else {
        if ((NSInteger)i < self.hiddenPosts) {
            [self showHiddenSeenPosts];
        }
        [_webViewJavaScriptBridge callHandler:@"jumpToPostWithID" data:topPost.postID];
    }
}

- (void)renderPosts
{
    [self loadBlankPage];
    _webViewDidLoadOnce = NO;
    
    NSMutableDictionary *context = [NSMutableDictionary new];
    NSError *error;
    NSString *script = LoadJavaScriptResources(@[ @"WebViewJavascriptBridge.js.txt", @"zepto.min.js", @"common.js", @"posts-view.js" ], &error);
    if (!script) {
        NSLog(@"%s error loading scripts: %@", __PRETTY_FUNCTION__, error);
        return;
    }
    context[@"script"] = script;
	context[@"version"] = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    context[@"userInterfaceIdiom"] = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? @"ipad" : @"iphone";
    context[@"stylesheet"] = self.theme[@"postsViewCSS"];
    NSMutableArray *postViewModels = [NSMutableArray new];
    NSRange range = NSMakeRange(self.hiddenPosts, 0);
    if ((NSInteger)self.posts.count > self.hiddenPosts) {
        range.length = self.posts.count - self.hiddenPosts;
    }
    if (self.posts.count >= NSMaxRange(range)) {
        for (Post *post in [self.posts subarrayWithRange:range]) {
            [postViewModels addObject:[[PostViewModel alloc] initWithPost:post]];
        }
    }
    context[@"posts"] = postViewModels;
    if (self.advertisementHTML.length) {
        context[@"advertisementHTML"] = self.advertisementHTML;
    }
    if (postViewModels.count > 0 && self.page > 0 && self.page >= self.numberOfPages) {
        context[@"endMessage"] = @"End of the thread";
    }
    int fontScalePercentage = [AwfulSettings sharedSettings].fontScale;
    if (fontScalePercentage != 100) {
        context[@"fontScalePercentage"] = @(fontScalePercentage);
    }
    if ([AwfulSettings sharedSettings].username.length > 0) {
        context[@"loggedInUsername"] = [AwfulSettings sharedSettings].username;
    }
    context[@"externalStylesheet"] = [AwfulPostsViewExternalStylesheetLoader loader].stylesheet;
    if (self.thread.threadID.length > 0) {
        context[@"threadID"] = self.thread.threadID;
    }
    if (self.thread.forum.forumID.length > 0) {
        context[@"forumID"] = self.thread.forum.forumID;
    }
    NSString *HTML = [GRMustacheTemplate renderObject:context fromResource:@"PostsView" bundle:nil error:&error];
    if (!HTML) {
        NSLog(@"%s error loading posts view HTML: %@", __PRETTY_FUNCTION__, error);
    }
    [self.webView loadHTMLString:HTML baseURL:[AwfulForumsClient client].baseURL];
}

- (void)loadBlankPage
{
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"about:blank"]];
    [self.webView loadRequest:request];
}

- (Theme *)theme
{
    Forum *forum = self.thread.forum;
    return forum.forumID.length > 0 ? [Theme currentThemeForForum:self.thread.forum] : [Theme currentTheme];
}

- (UIBarButtonItem *)composeItem
{
    if (_composeItem) return _composeItem;
    _composeItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"compose"] style:UIBarButtonItemStylePlain target:nil action:nil];
    _composeItem.accessibilityLabel = @"Reply to thread";
    __weak __typeof__(self) weakSelf = self;
    _composeItem.awful_actionBlock = ^(UIBarButtonItem *sender) {
        __typeof__(self) self = weakSelf;
        if (!self.replyWorkspace) {
            self.replyWorkspace = [[ReplyWorkspace alloc] initWithThread:self.thread];
            self.replyWorkspace.completion = self.replyCompletionBlock;
        }
        [self presentViewController:self.replyWorkspace.viewController animated:YES completion:nil];
    };
    return _composeItem;
}

typedef void (^ReplyCompletion)(BOOL, BOOL);

- (ReplyCompletion)replyCompletionBlock
{
    __weak __typeof__(self) weakSelf = self;
    return ^(BOOL saveDraft, BOOL didSucceed) {
        __typeof__(self) self = weakSelf;
        if (!saveDraft) {
            self.replyWorkspace = nil;
        }
        if (didSucceed) {
            [self loadPage:AwfulThreadPageNextUnread updatingCache:YES];
        }
        [self dismissViewControllerAnimated:YES completion:nil];
    };
}

- (UIBarButtonItem *)settingsItem
{
    if (_settingsItem) return _settingsItem;
    _settingsItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"page-settings"] style:UIBarButtonItemStylePlain target:nil action:nil];
    _settingsItem.accessibilityLabel = @"Settings";
    __weak __typeof__(self) weakSelf = self;
    _settingsItem.awful_actionBlock = ^(UIBarButtonItem *sender) {
        __typeof__(self) self = weakSelf;
        PostsPageSettingsViewController *settings = [[PostsPageSettingsViewController alloc] initWithForum:self.thread.forum];
        settings.selectedTheme = self.theme;
        [self presentViewController:settings animated:YES completion:nil];
        settings.popoverPresentationController.barButtonItem = sender;
    };
    return _settingsItem;
}

- (UIBarButtonItem *)backItem
{
    if (_backItem) return _backItem;
    _backItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"arrowleft"] style:UIBarButtonItemStylePlain target:nil action:nil];
    _backItem.accessibilityLabel = @"Previous page";
    __weak __typeof__(self) weakSelf = self;
    _backItem.awful_actionBlock = ^(UIBarButtonItem *sender) {
        __typeof__(self) self = weakSelf;
        if (self.page > 1) {
            [self loadPage:self.page - 1 updatingCache:YES];
        }
    };
    return _backItem;
}

- (UIBarButtonItem *)currentPageItem
{
    if (_currentPageItem) return _currentPageItem;
    _currentPageItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
    _currentPageItem.possibleTitles = [NSSet setWithObject:@"2345 / 2345"];
    _currentPageItem.accessibilityHint = @"Opens page picker";
    __weak __typeof__(self) weakSelf = self;
    _currentPageItem.awful_actionBlock = ^(UIBarButtonItem *sender) {
        __typeof__(self) self = weakSelf;
        if (self.loadingView) return;
        Selectotron *selectotron = [[Selectotron alloc] initWithPostsViewController:self];
        [self presentViewController:selectotron animated:YES completion:nil];
        selectotron.popoverPresentationController.barButtonItem = sender;
    };
    return _currentPageItem;
}

- (UIBarButtonItem *)forwardItem
{
    if (_forwardItem) return _forwardItem;
    _forwardItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"arrowright"] style:UIBarButtonItemStylePlain target:nil action:nil];
    _forwardItem.accessibilityLabel = @"Next page";
    __weak __typeof__(self) weakSelf = self;
    _forwardItem.awful_actionBlock = ^(UIBarButtonItem *sender) {
        __typeof__(self) self = weakSelf;
        if (self.page < self.numberOfPages && self.page > 0) {
            [self loadPage:self.page + 1 updatingCache:YES];
        }
    };
    return _forwardItem;
}

- (UIBarButtonItem *)actionsItem
{
    if (_actionsItem) return _actionsItem;
    _actionsItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"action"] style:UIBarButtonItemStylePlain target:nil action:nil];
    __weak __typeof__(self) weakSelf = self;
    _actionsItem.awful_actionBlock = ^(UIBarButtonItem *sender) {
        __typeof__(self) self = weakSelf;
        InAppActionViewController *actionViewController = [InAppActionViewController new];
        actionViewController.title = self.title;
        NSMutableArray *items = [NSMutableArray new];
        AwfulIconActionItem *copyURLItem = [AwfulIconActionItem itemWithType:AwfulIconActionItemTypeCopyURL action:^{
            NSURLComponents *components = [NSURLComponents componentsWithString:@"http://forums.somethingawful.com/showthread.php"];
            NSMutableArray *queryParts = [NSMutableArray new];
            [queryParts addObject:[NSString stringWithFormat:@"threadid=%@", self.thread.threadID]];
            [queryParts addObject:@"perpage=40"];
            if (self.page > 1) {
                [queryParts addObject:[NSString stringWithFormat:@"pagenumber=%@", @(self.page)]];
            }
            components.query = [queryParts componentsJoinedByString:@"&"];
            NSURL *URL = components.URL;
            [AwfulSettings sharedSettings].lastOfferedPasteboardURL = URL.absoluteString;
            [UIPasteboard generalPasteboard].awful_URL = URL;
        }];
        copyURLItem.title = @"Copy URL";
        [items addObject:copyURLItem];
        [items addObject:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeVote action:^{
            UIAlertController *actionSheet = [UIAlertController actionSheet];
            for (int i = 5; i >= 1; i--) {
                [actionSheet addActionWithTitle:[@(i) stringValue] handler:^{
                    MRProgressOverlayView *overlay = [MRProgressOverlayView showOverlayAddedTo:self.view
                                                                                         title:[NSString stringWithFormat:@"Voting %i", i]
                                                                                          mode:MRProgressOverlayViewModeIndeterminate
                                                                                      animated:YES];
                    overlay.tintColor = self.theme[@"tintColor"];
                    [[AwfulForumsClient client] rateThread:self.thread :i andThen:^(NSError *error) {
                        if (error) {
                            [overlay dismiss:NO];
                            [self presentViewController:[UIAlertController alertWithTitle:@"Vote Failed" error:error] animated:YES completion:nil];
                        } else {
                            overlay.mode = MRProgressOverlayViewModeCheckmark;
                            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                [overlay dismiss:YES];
                            });
                        }
                    }];
                }];
            }
            [actionSheet addCancelActionWithHandler:nil];
            [self presentViewController:actionSheet animated:NO completion:nil];
            actionSheet.popoverPresentationController.barButtonItem = sender;
        }]];
        
        AwfulIconActionItemType bookmarkItemType;
        if (self.thread.bookmarked) {
            bookmarkItemType = AwfulIconActionItemTypeRemoveBookmark;
        } else {
            bookmarkItemType = AwfulIconActionItemTypeAddBookmark;
        }
        [items addObject:[AwfulIconActionItem itemWithType:bookmarkItemType action:^{
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
        
        actionViewController.items = items;
        [self presentViewController:actionViewController animated:YES completion:nil];
        actionViewController.popoverPresentationController.barButtonItem = sender;
    };
    return _actionsItem;
}

- (void)settingsDidChange:(NSNotification *)note
{
    if (![self isViewLoaded]) return;
    
    NSString *settingKey = note.userInfo[AwfulSettingsDidChangeSettingKey];
    if ([settingKey isEqualToString:AwfulSettingsKeys.showAvatars]) {
        [_webViewJavaScriptBridge callHandler:@"showAvatars" data:@([AwfulSettings sharedSettings].showAvatars)];
    } else if ([settingKey isEqualToString:AwfulSettingsKeys.username]) {
        [_webViewJavaScriptBridge callHandler:@"highlightMentionUsername" data:[AwfulSettings sharedSettings].username];
    } else if ([settingKey isEqualToString:AwfulSettingsKeys.fontScale]) {
        [_webViewJavaScriptBridge callHandler:@"fontScale" data:@([AwfulSettings sharedSettings].fontScale)];
    } else if ([settingKey isEqualToString:AwfulSettingsKeys.showImages]) {
        if ([AwfulSettings sharedSettings].showImages) {
            [_webViewJavaScriptBridge callHandler:@"loadLinkifiedImages"];
        }
    } else if ([settingKey isEqualToString:AwfulSettingsKeys.handoffEnabled]) {
        if (self.visible) {
            [self configureUserActivityIfPossible];
        }
    }
}

- (void)themeDidChange
{
    [super themeDidChange];
    
    Theme *theme = self.theme;
    self.postsView.webView.scrollView.indicatorStyle = theme.scrollIndicatorStyle;
    [_webViewJavaScriptBridge callHandler:@"changeStylesheet" data:theme[@"postsViewCSS"]];
    
    if (self.loadingView) {
        [self.loadingView removeFromSuperview];
        self.loadingView = [AwfulLoadingView loadingViewForTheme:theme];
        [self.view addSubview:self.loadingView];
    }
    
    AwfulPostsViewTopBar *topBar = self.postsView.topBar;
    topBar.backgroundColor = theme[@"postsTopBarBackgroundColor"];
    void (^configureButton)(UIButton *) = ^(UIButton *button){
        [button setTitleColor:theme[@"postsTopBarTextColor"] forState:UIControlStateNormal];
        [button setTitleColor:[theme[@"postsTopBarTextColor"] colorWithAlphaComponent:.5] forState:UIControlStateDisabled];
        button.backgroundColor = theme[@"postsTopBarBackgroundColor"];
    };
    configureButton(topBar.parentForumButton);
    configureButton(topBar.previousPostsButton);
    configureButton(topBar.scrollToBottomButton);
    
    [self.messageViewController themeDidChange];
}

- (void)refetchPosts
{
    if (!self.thread || self.page < 1) {
        self.posts = nil;
        return;
    }
    
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:[Post entityName]];
    NSInteger lowIndex = (self.page - 1) * 40 + 1;
    NSInteger highIndex = self.page * 40;
    NSString *indexKey;
    if (self.author) {
        indexKey = @"filteredThreadIndex";
    } else {
        indexKey = @"threadIndex";
    }
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"thread = %@ AND %d <= %K AND %K <= %d",
                         self.thread, lowIndex, indexKey, indexKey, highIndex];
    if (self.author) {
        NSPredicate *and = [NSPredicate predicateWithFormat:@"author.userID = %@", self.author.userID];
        fetchRequest.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:
                             @[ fetchRequest.predicate, and ]];
    }
    fetchRequest.sortDescriptors = @[ [NSSortDescriptor sortDescriptorWithKey:indexKey ascending:YES] ];
    
    NSError *error;
    NSArray *posts = [self.thread.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (!posts) {
        NSLog(@"%s error fetching posts: %@", __PRETTY_FUNCTION__, error);
    }
    self.posts = posts;
}

- (void)updateUserInterface
{
    self.title = [self.thread.title stringByCollapsingWhitespace];
    
    if (self.page == AwfulThreadPageLast || self.page == AwfulThreadPageNextUnread || self.posts.count == 0) {
        [self showLoadingView];
    } else {
        [self clearLoadingMessage];
    }
    
    self.postsView.topBar.scrollToBottomButton.enabled = [self.posts count] > 0;
    self.postsView.topBar.previousPostsButton.enabled = self.hiddenPosts > 0;
    
    SVPullToRefreshView *refresh = self.postsView.webView.scrollView.pullToRefreshView;
    if (self.numberOfPages > self.page) {
        [refresh setTitle:@"Pull for next page…" forState:SVPullToRefreshStateStopped];
        [refresh setTitle:@"Release for next page…" forState:SVPullToRefreshStateTriggered];
        [refresh setTitle:@"Loading next page…" forState:SVPullToRefreshStateLoading];
    } else {
        [refresh setTitle:@"Pull to refresh…" forState:SVPullToRefreshStateStopped];
        [refresh setTitle:@"Release to refresh…" forState:SVPullToRefreshStateTriggered];
        [refresh setTitle:@"Refreshing…" forState:SVPullToRefreshStateLoading];
    }
    
    self.backItem.enabled = self.page > 1;
    if (self.page > 0 && self.numberOfPages > 0) {
        self.currentPageItem.title = [NSString stringWithFormat:@"%ld / %ld", (long)self.page, (long)self.numberOfPages];
        self.currentPageItem.accessibilityLabel = [NSString stringWithFormat:@"Page %ld of %ld", (long)self.page, (long)self.numberOfPages];
    } else {
        self.currentPageItem.title = @"";
    }
    self.forwardItem.enabled = self.page > 0 && self.page < self.numberOfPages;
    self.composeItem.enabled = !self.thread.closed;
}

- (void)showLoadingView
{
    if (!self.loadingView) {
        self.loadingView = [AwfulLoadingView loadingViewForTheme:self.theme];
    }
    [self.view addSubview:self.loadingView];
}

- (void)clearLoadingMessage
{
    [self.loadingView removeFromSuperview];
    self.loadingView = nil;
}

- (void)setHiddenPosts:(NSInteger)hiddenPosts
{
    if (_hiddenPosts == hiddenPosts) return;
    _hiddenPosts = hiddenPosts;
    [self updateUserInterface];
}

- (void)loadNextPageOrRefresh
{
    // There's surprising sublety in figuring out what "next page" means.
    AwfulThreadPage nextPage;
    
    // When we're showing a partial page, just fill in the rest by reloading the current page.
    if (self.posts.count < 40) {
        nextPage = self.page;
    }
    
    // When we've got a full page but we're not sure there's another, just reload. The next page arrow will light up if we've found more pages. This is pretty subtle and not at all ideal. (Though doing something like going to the next unread page is even more confusing!)
    else if (self.page == self.numberOfPages) {
        nextPage = self.page;
    }
    
    // Otherwise we know there's another page, so fire away.
    else {
        nextPage = self.page + 1;
    }
    
    [self loadPage:nextPage updatingCache:YES];
}

- (void)goToParentForum
{
    NSString *url = [NSString stringWithFormat:@"awful://forums/%@", self.thread.forum.forumID];
    [[AwfulAppDelegate instance] openAwfulURL:[NSURL URLWithString:url]];
}

- (void)showHiddenSeenPosts
{
    NSMutableArray *HTMLFragments = [NSMutableArray new];
    NSUInteger end = self.hiddenPosts;
    self.hiddenPosts = 0;
    for (NSUInteger i = 0; i < end; i++) {
        NSString *HTML = [self renderedPostAtIndex:i];
        [HTMLFragments addObject:HTML];
    }
    NSString *HTML = [HTMLFragments componentsJoinedByString:@"\n"];
    [_webViewJavaScriptBridge callHandler:@"prependPosts" data:HTML];
}

- (void)scrollToBottom
{
    UIScrollView *scrollView = self.postsView.webView.scrollView;
    [scrollView scrollRectToVisible:CGRectMake(0, scrollView.contentSize.height - 1, 1, 1) animated:YES];
}

- (void)didLongPressOnPostsView:(UILongPressGestureRecognizer *)sender
{
    if (sender.state != UIGestureRecognizerStateBegan) return;
    
    CGPoint location = [sender locationInView:self.postsView.webView];
    UIScrollView *scrollView = self.webView.scrollView;
    location.y -= scrollView.contentInset.top;
    CGFloat offsetY = scrollView.contentOffset.y;
    if (offsetY < 0) {
        location.y += offsetY;
    }
    NSDictionary *data = @{ @"x": @(location.x), @"y": @(location.y) };
    __weak __typeof__(self) weakSelf = self;
    [_webViewJavaScriptBridge callHandler:@"interestingElementsAtPoint" data:data responseCallback:^(NSDictionary *elementInfo) {
        __typeof__(self) self = weakSelf;
        [self.postsView.webView awful_evalJavaScript:@"Awful.preventNextClickEvent()"];
        
        if (elementInfo.count == 0) return;
        
        BOOL ok = [URLMenuPresenter presentInterestingElements:elementInfo fromViewController:self fromWebView:self.webView];
        if (!ok && !elementInfo[@"unspoiledLink"]) {
            NSLog(@"%s unexpected interesting elements for data %@ response: %@", __PRETTY_FUNCTION__, data, elementInfo);
        }
    }];
}

- (NSString *)renderedPostAtIndex:(NSInteger)index
{
    Post *post = self.posts[index];
    PostViewModel *viewModel = [[PostViewModel alloc] initWithPost:post];
    NSError *error;
    NSString *HTML = [GRMustacheTemplate renderObject:viewModel fromResource:@"Post" bundle:nil error:&error];
    if (!HTML) {
        NSLog(@"error rendering post at index %@: %@", @(index), error);
    }
    return HTML;
}

- (void)readIgnoredPostAtIndex:(NSUInteger)index
{
    Post *post = self.posts[index];
    __weak __typeof__(self) weakSelf = self;
    [[AwfulForumsClient client] readIgnoredPost:post andThen:^(NSError *error) {
        __typeof__(self) self = weakSelf;
        if (error) {
            [self presentViewController:[UIAlertController alertWithNetworkError:error] animated:YES completion:nil];
            return;
        }
        
        // Grabbing the index here ensures we're still on the same page as the post to replace, and that we have the right post index (in case it got hidden).
        NSInteger i = [self.posts indexOfObject:post];
        if (i == NSNotFound) return;
        i -= self.hiddenPosts;
        if (i >= 0) {
            NSDictionary *data = @{ @"index": @(i),
                                    @"HTML": [self renderedPostAtIndex:index] };
            [_webViewJavaScriptBridge callHandler:@"postHTMLAtIndex" data:data];
        }
    }];
}

- (void)didTapUserHeaderWithRect:(CGRect)rect forPostAtIndex:(NSUInteger)postIndex
{
    Post *post = self.posts[postIndex + self.hiddenPosts];
    User *user = post.author;
    InAppActionViewController *actionViewController = [InAppActionViewController new];
    NSMutableArray *items = [NSMutableArray new];
    
	[items addObject:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeUserProfile action:^{
        ProfileViewController *profileViewController = [[ProfileViewController alloc] initWithUser:user];
        [self presentViewController:[profileViewController enclosingNavigationController] animated:YES completion:nil];
	}]];
    
	if (!self.author) {
		[items addObject:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeSingleUsersPosts action:^{
            PostsPageViewController *postsView = [[PostsPageViewController alloc] initWithThread:self.thread author:user];
            postsView.restorationIdentifier = @"Just their posts";
            [postsView loadPage:1 updatingCache:YES];
            [self.navigationController pushViewController:postsView animated:YES];
        }]];
	}
    
	if ([AwfulSettings sharedSettings].canSendPrivateMessages && user.canReceivePrivateMessages) {
        if (![user.userID isEqual:[AwfulSettings sharedSettings].userID]) {
            [items addObject:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeSendPrivateMessage action:^{
                self.messageViewController = [[MessageComposeViewController alloc] initWithRecipient:user];
                self.messageViewController.delegate = self;
                self.messageViewController.restorationIdentifier = @"New PM from posts view";
                [self presentViewController:[self.messageViewController enclosingNavigationController] animated:YES completion:nil];
            }]];
        }
	}
    
	[items addObject:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeRapSheet action:^{
        RapSheetViewController *rapSheet = [[RapSheetViewController alloc] initWithUser:user];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            [self presentViewController:[rapSheet enclosingNavigationController] animated:YES completion:nil];
        } else {
            [self.navigationController pushViewController:rapSheet animated:YES];
        }
	}]];
    
    actionViewController.items = items;
    actionViewController.popoverPositioningBlock = ^(CGRect *sourceRect, UIView * __autoreleasing *sourceView) {
        NSString *rectString = [self.webView awful_evalJavaScript:@"HeaderRectForPostAtIndex(%lu)", (unsigned long)postIndex];
        *sourceRect = [self.webView awful_rectForElementBoundingRect:rectString];
        *sourceView = self.webView;
    };
    [self presentViewController:actionViewController animated:YES completion:nil];
}

- (void)didTapActionButtonWithRect:(CGRect)rect forPostAtIndex:(NSUInteger)postIndex
{
    NSAssert(postIndex + self.hiddenPosts < self.posts.count, @"post %lu beyond range (hiding %ld posts)", (unsigned long)postIndex, (long)self.hiddenPosts);
    
    Post *post = self.posts[postIndex + self.hiddenPosts];
    NSString *possessiveUsername = [NSString stringWithFormat:@"%@'s", post.author.username];
    if ([post.author.username isEqualToString:[AwfulSettings sharedSettings].username]) {
        possessiveUsername = @"Your";
    }
    
    /// Filled in once the action popover is presented.
    __block CGRect popoverSourceRect;
    __block UIView *popoverSourceView;

    NSMutableArray *items = [NSMutableArray new];
    __weak __typeof__(self) weakSelf = self;
    
    AwfulIconActionItem *shareItem = [AwfulIconActionItem itemWithType:AwfulIconActionItemTypeCopyURL action:^{
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
        
        NSArray *browserActivities = @[[TUSafariActivity new], [ARChromeActivity new]];
        UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[URL]
                                                                                             applicationActivities:browserActivities];
        activityViewController.completionWithItemsHandler = ^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
            if (completed && [activityType isEqualToString:UIActivityTypeCopyToPasteboard]) {
                [AwfulSettings sharedSettings].lastOfferedPasteboardURL = URL.absoluteString;
            }
        };
        [self presentViewController:activityViewController animated:NO completion:nil];
        UIPopoverPresentationController *popover = activityViewController.popoverPresentationController;
        popover.sourceView = popoverSourceView;
        popover.sourceRect = popoverSourceRect;
    }];
    shareItem.title = @"Share URL";
    [items addObject:shareItem];
    
    if (!self.author) {
        [items addObject:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeMarkReadUpToHere action:^{
            [[AwfulForumsClient client] markThreadReadUpToPost:post andThen:^(NSError *error) {
                __typeof__(self) self = weakSelf;
                if (error) {
                    [self presentViewController:[UIAlertController alertWithTitle:@"Could Not Mark Read" error:error] animated:YES completion:nil];
                } else {
                    post.thread.seenPosts = post.threadIndex;
                    [self->_webViewJavaScriptBridge callHandler:@"markReadUpToPostWithID" data:post.postID];
                    MRProgressOverlayView *overlay = [MRProgressOverlayView showOverlayAddedTo:self.view
                                                                                         title:@"Marked Read"
                                                                                          mode:MRProgressOverlayViewModeCheckmark
                                                                                      animated:YES];
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [overlay dismiss:YES];
                    });
                }
            }];
        }]];
    }
    
    if (post.editable) {
        [items addObject:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeEditPost action:^{
            [[AwfulForumsClient client] findBBcodeContentsWithPost:post andThen:^(NSError *error, NSString *text) {
                __typeof__(self) self = weakSelf;
                if (error) {
                    [self presentViewController:[UIAlertController alertWithTitle:@"Could Not Edit Post" error:error] animated:YES completion:nil];
                    return;
                }
                self.replyWorkspace = [[ReplyWorkspace alloc] initWithPost:post];
                self.replyWorkspace.completion = self.replyCompletionBlock;
                [self presentViewController:self.replyWorkspace.viewController animated:YES completion:nil];
            }];
        }]];
    }
    
    if (!self.thread.closed) {
        [items addObject:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeQuotePost action:^{
            if (!self.replyWorkspace) {
                self.replyWorkspace = [[ReplyWorkspace alloc] initWithThread:self.thread];
                self.replyWorkspace.completion = self.replyCompletionBlock;
            }
            
            __weak __typeof__(self) welf = self;
            
            [self.replyWorkspace quotePost:post completion:^(NSError *error) {
                __typeof__(self) self = welf;
                
                if (error) {
                    UIAlertController *alert = [UIAlertController alertWithNetworkError:error];
                    [self presentViewController:alert animated:YES completion:nil];
                } else {
                    [self presentViewController:self.replyWorkspace.viewController animated:YES completion:nil];
                }
            }];
        }]];
    }
    
    [items addObject:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeReportPost action:^{
        ReportPostViewController *report = [[ReportPostViewController alloc] initWithPost:post];
        [self presentViewController:[report enclosingNavigationController] animated:YES completion:nil];
    }]];
    
    if (self.author) {
        [items addObject:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeShowInThread action:^{
            // This will add the thread to the navigation stack, giving us thread->author->thread.
            NSString *url = [NSString stringWithFormat:@"awful://posts/%@", post.postID];
            [[AwfulAppDelegate instance] openAwfulURL:[NSURL URLWithString:url]];
        }]];
    }
    
    InAppActionViewController *actionViewController = [InAppActionViewController new];
    actionViewController.title = [NSString stringWithFormat:@"%@ Post", possessiveUsername];
    actionViewController.items = items;
    actionViewController.popoverPositioningBlock = ^(CGRect *sourceRect, UIView * __autoreleasing *sourceView) {
        NSString *rectString = [self.webView awful_evalJavaScript:@"ActionButtonRectForPostAtIndex(%lu)", (unsigned long)postIndex];
        popoverSourceRect = [self.webView awful_rectForElementBoundingRect:rectString];
        *sourceRect = popoverSourceRect;
        popoverSourceView = self.webView;
        *sourceView = popoverSourceView;
    };
    [self presentViewController:actionViewController animated:YES completion:nil];
}

- (void)externalStylesheetDidUpdate:(NSNotification *)notification
{
    [_webViewJavaScriptBridge callHandler:@"changeExternalStylesheet" data:notification.object];
}

- (AwfulPostsView *)postsView
{
    return (AwfulPostsView *)self.view;
}

- (UIWebView *)webView
{
    return self.postsView.webView;
}

#pragma mark - UIViewController

- (void)setTitle:(NSString *)title
{
    [super setTitle:title];
    self.navigationItem.titleLabel.text = title;
}

- (void)loadView
{
    self.view = [AwfulPostsView new];
    
    AwfulPostsViewTopBar *topBar = self.postsView.topBar;
    [topBar.parentForumButton addTarget:self action:@selector(goToParentForum) forControlEvents:UIControlEventTouchUpInside];
    [topBar.previousPostsButton addTarget:self action:@selector(showHiddenSeenPosts) forControlEvents:UIControlEventTouchUpInside];
    topBar.previousPostsButton.enabled = self.hiddenPosts > 0;
    [topBar.scrollToBottomButton addTarget:self action:@selector(scrollToBottom) forControlEvents:UIControlEventTouchUpInside];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(didLongPressOnPostsView:)];
    longPress.delegate = self;
    [self.webView addGestureRecognizer:longPress];
    
    _webViewNetworkActivityIndicatorManager = [[AwfulWebViewNetworkActivityIndicatorManager alloc] initWithNextDelegate:self];
    __weak __typeof__(self) weakSelf = self;
    _webViewJavaScriptBridge = [WebViewJavascriptBridge bridgeForWebView:self.webView
                                                         webViewDelegate:_webViewNetworkActivityIndicatorManager
                                                                 handler:^(id data, WVJBResponseCallback _)
    {
        NSLog(@"%s %@", __PRETTY_FUNCTION__, data);
    }];
    [_webViewJavaScriptBridge registerHandler:@"didTapUserHeader" handler:^(NSDictionary *data, WVJBResponseCallback _) {
        __typeof__(self) self = weakSelf;
        CGRect rect = [self.webView awful_rectForElementBoundingRect:data[@"rect"]];
        NSUInteger postIndex = [data[@"postIndex"] unsignedIntegerValue];
        [self didTapUserHeaderWithRect:rect forPostAtIndex:postIndex];
    }];
    [_webViewJavaScriptBridge registerHandler:@"didTapActionButton" handler:^(NSDictionary *data, WVJBResponseCallback _) {
        __typeof__(self) self = weakSelf;
        CGRect rect = [self.webView awful_rectForElementBoundingRect:data[@"rect"]];
        NSUInteger postIndex = [data[@"postIndex"] unsignedIntegerValue];
        [self didTapActionButtonWithRect:rect forPostAtIndex:postIndex];
    }];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(externalStylesheetDidUpdate:)
                                                 name:AwfulPostsViewExternalStylesheetLoaderDidUpdateNotification
                                               object:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // Doing this here avoids SVPullToRefresh's poor interaction with automaticallyAdjustsScrollViewInsets.
    __weak __typeof__(self) weakSelf = self;
    [self.postsView.webView.scrollView addPullToRefreshWithActionHandler:^{
        __typeof__(self) self = weakSelf;
        [self loadNextPageOrRefresh];
    } position:SVPullToRefreshPositionBottom];
    
    [self configureUserActivityIfPossible];
}

- (void)configureUserActivityIfPossible
{
    if (self.page >= 1) {
        if ([AwfulSettings sharedSettings].handoffEnabled) {
            self.userActivity = [[NSUserActivity alloc] initWithActivityType:Handoff.ActivityTypeBrowsingPosts];
            self.userActivity.needsSave = YES;
        }
    } else {
        self.userActivity = nil;
    }
}

- (void)updateUserActivityState:(NSUserActivity *)activity
{
    activity.title = self.thread.title;
    [activity addUserInfoEntriesFromDictionary:@{Handoff.InfoThreadIDKey: self.thread.threadID,
                                                 Handoff.InfoPageKey: @(self.page)}];
    if (self.author) {
        [activity addUserInfoEntriesFromDictionary:@{Handoff.InfoFilteredThreadUserIDKey: self.author.userID}];
    }
    
    NSMutableString *relativeString = [NSMutableString new];
    [relativeString appendFormat:@"/showthread.php?threadid=%@&perpage=40", self.thread.threadID];
    if (self.page > 1) {
        [relativeString appendFormat:@"&pagenumber=%@", @(self.page)];
    }
    if (self.author) {
        [relativeString appendFormat:@"&userid=%@", self.author.userID];
    }
    activity.webpageURL = [NSURL URLWithString:relativeString relativeToURL:[AwfulForumsClient client].baseURL];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    self.userActivity = nil;
}

#pragma mark - AwfulComposeTextViewControllerDelegate

- (void)composeTextViewController:(ComposeTextViewController *)composeTextViewController
didFinishWithSuccessfulSubmission:(BOOL)success
                  shouldKeepDraft:(BOOL)keepDraft
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

#pragma mark - UIWebViewDelegate

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    NSURL *URL = request.URL;
    
    // YouTube embeds can take over the frame when someone taps the video title. Here we try to detect that and treat it as if a link was tapped.
    if (navigationType != UIWebViewNavigationTypeLinkClicked && [URL.host.lowercaseString hasSuffix:@"www.youtube.com"] && [URL.path.lowercaseString hasPrefix:@"/watch"]) {
        navigationType = UIWebViewNavigationTypeLinkClicked;
    }
    
    if (navigationType == UIWebViewNavigationTypeLinkClicked) {
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
            [[[URLMenuPresenter alloc] initWithLinkURL:URL imageURL:nil] presentInDefaultBrowserFromViewController:self];
        } else {
            [[UIApplication sharedApplication] openURL:URL];
        }
        return NO;
    }
    
    return YES;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    if (!_webViewDidLoadOnce && ![webView.request.URL isEqual:[NSURL URLWithString:@"about:blank"]]) {
        _webViewDidLoadOnce = YES;
        if (_jumpToPostIDAfterLoading) {
            [_webViewJavaScriptBridge callHandler:@"jumpToPostWithID" data:_jumpToPostIDAfterLoading];
        } else if (_scrollToFractionAfterLoading > 0) {
            webView.awful_fractionalContentOffset = _scrollToFractionAfterLoading;
        }
        _jumpToPostIDAfterLoading = nil;
        _scrollToFractionAfterLoading = 0;
        [self clearLoadingMessage];
    }
}

#pragma mark - State Preservation and Restoration

+ (UIViewController *)viewControllerWithRestorationIdentifierPath:(NSArray *)identifierComponents coder:(NSCoder *)coder
{
    // AwfulObjectKey was introduced in Awful 3.2.
    ThreadKey *threadKey = [coder decodeObjectForKey:ThreadKeyKey];
    if (!threadKey) {
        NSString *threadID = [coder decodeObjectForKey:obsolete_ThreadIDKey];
        threadKey = [[ThreadKey alloc] initWithThreadID:threadID];
    }
    UserKey *userKey = [coder decodeObjectForKey:AuthorUserKeyKey];
    if (!userKey) {
        NSString *userID = [coder decodeObjectForKey:obsolete_AuthorUserIDKey];
        if (userID) {
            userKey = [[UserKey alloc] initWithUserID:userID username:nil];
        }
    }
    NSManagedObjectContext *managedObjectContext = [AwfulAppDelegate instance].managedObjectContext;
    Thread *thread = [Thread objectForKey:threadKey inManagedObjectContext:managedObjectContext];
    User *author;
    if (userKey) {
        author = [User objectForKey:userKey inManagedObjectContext:managedObjectContext];
    }
    PostsPageViewController *postsView = [[PostsPageViewController alloc] initWithThread:thread author:author];
    postsView.restorationIdentifier = identifierComponents.lastObject;
    return postsView;
}

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super encodeRestorableStateWithCoder:coder];
    [coder encodeObject:self.thread.objectKey forKey:ThreadKeyKey];
    [coder encodeInteger:self.page forKey:PageKey];
    [coder encodeObject:self.author.objectKey forKey:AuthorUserKeyKey];
    [coder encodeInteger:self.hiddenPosts forKey:HiddenPostsKey];
    [coder encodeObject:self.messageViewController forKey:MessageViewControllerKey];
    [coder encodeObject:self.advertisementHTML forKey:AdvertisementHTMLKey];
    [coder encodeFloat:self.webView.awful_fractionalContentOffset forKey:ScrolledFractionOfContentKey];
    [coder encodeObject:self.replyWorkspace forKey:ReplyWorkspaceKey];
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
    _restoringState = YES;
    [super decodeRestorableStateWithCoder:coder];
    self.messageViewController = [coder decodeObjectForKey:MessageViewControllerKey];
    self.messageViewController.delegate = self;
    self.hiddenPosts = [coder decodeIntegerForKey:HiddenPostsKey];
    self.page = [coder decodeIntegerForKey:PageKey];
    [self loadPage:self.page updatingCache:NO];
    if (self.posts.count == 0) {
        [self loadPage:self.page updatingCache:YES];
    }
    self.advertisementHTML = [coder decodeObjectForKey:AdvertisementHTMLKey];
    _scrollToFractionAfterLoading = [coder decodeFloatForKey:ScrolledFractionOfContentKey];
    self.replyWorkspace = [coder decodeObjectForKey:ReplyWorkspaceKey];
    self.replyWorkspace.completion = self.replyCompletionBlock;
}

- (void)applicationFinishedRestoringState
{
    _restoringState = NO;
}

static NSString * const ThreadKeyKey = @"ThreadKey";
static NSString * const obsolete_ThreadIDKey = @"AwfulThreadID";
static NSString * const PageKey = @"AwfulCurrentPage";
static NSString * const AuthorUserKeyKey = @"AuthorUserKey";
static NSString * const obsolete_AuthorUserIDKey = @"AwfulAuthorUserID";
static NSString * const HiddenPostsKey = @"AwfulHiddenPosts";
static NSString * const ReplyViewControllerKey = @"AwfulReplyViewController";
static NSString * const MessageViewControllerKey = @"AwfulMessageViewController";
static NSString * const AdvertisementHTMLKey = @"AwfulAdvertisementHTML";
static NSString * const ScrolledFractionOfContentKey = @"AwfulScrolledFractionOfContentSize";
static NSString * const ReplyWorkspaceKey = @"Reply workspace";

@end
