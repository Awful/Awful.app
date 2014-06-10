//  AwfulPostsViewController.m
//
//  Copyright 2010 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPostsViewController.h"
#import "AwfulActionSheet+WebViewSheets.h"
#import "AwfulActionViewController.h"
#import "AwfulAlertView.h"
#import "AwfulAppDelegate.h"
#import "AwfulBrowserViewController.h"
#import "AwfulDateFormatters.h"
#import "AwfulExternalBrowser.h"
#import "AwfulForumsClient.h"
#import "AwfulImagePreviewViewController.h"
#import "AwfulJavaScript.h"
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
#import "AwfulWebViewNetworkActivityIndicatorManager.h"
#import <GRMustache.h>
#import <MRProgress/MRProgressOverlayView.h>
#import <SVPullToRefresh/SVPullToRefresh.h>
#import <WebViewJavascriptBridge.h>

@interface AwfulPostsViewController () <AwfulComposeTextViewControllerDelegate, UIGestureRecognizerDelegate, UIViewControllerRestoration, UIWebViewDelegate>

@property (assign, nonatomic) AwfulThreadPage page;

@property (weak, nonatomic) NSOperation *networkOperation;

@property (nonatomic) AwfulPageTopBar *topBar;
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

@property (strong, nonatomic) AwfulReplyViewController *replyViewController;
@property (strong, nonatomic) AwfulNewPrivateMessageViewController *messageViewController;

@property (copy, nonatomic) NSArray *posts;

@end

@implementation AwfulPostsViewController
{
    AwfulWebViewNetworkActivityIndicatorManager *_webViewNetworkActivityIndicatorManager;
    WebViewJavascriptBridge *_webViewJavaScriptBridge;
    BOOL _webViewDidLoadOnce;
    NSString *_jumpToPostIDAfterLoading;
    CGFloat _scrollToFractionAfterLoading;
    BOOL _restoringState;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
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

- (NSInteger)numberOfPages
{
    if (self.author) {
        return [self.thread numberOfPagesForSingleUser:self.author];
    } else {
        return self.thread.numberOfPages;
    }
}

- (void)loadPage:(AwfulThreadPage)page updatingCache:(BOOL)updateCache
{
    [self.networkOperation cancel];
    self.networkOperation = nil;
    
    BOOL reloadingSamePage = page == self.page;
    self.page = page;
    
    if (self.posts.count == 0 || !reloadingSamePage) {
        [self.postsView.pullToRefreshView stopAnimating];
        [self updateUserInterface];
        if (!_restoringState) {
            self.hiddenPosts = 0;
        }
        [self refetchPosts];
        [self renderPosts];
    }
    
    BOOL renderedCachedPosts = self.posts.count > 0;
    
    [self updateUserInterface];
    
    if (!updateCache) {
        [self clearLoadingMessage];
        return;
    }
    
    __weak __typeof__(self) weakSelf = self;
    self.networkOperation = [[AwfulForumsClient client] listPostsInThread:self.thread
                                                                writtenBy:self.author
                                                                   onPage:self.page
                                                                  andThen:^(NSError *error, NSArray *posts, NSUInteger firstUnreadPost, NSString *advertisementHTML)
    {
        __typeof__(self) self = weakSelf;
        
        // We can get out-of-sync here as there's no cancelling the overall scraping operation. Make sure we've got the right page.
        if (page != self.page) return;
        
        if (error) {
            [self clearLoadingMessage];
            BOOL offlineMode = ![AwfulForumsClient client].reachable && [error.domain isEqualToString:NSURLErrorDomain];
            if (self.posts.count == 0 || !offlineMode) {
                [AwfulAlertView showWithTitle:@"Could Not Load Page" error:error buttonTitle:@"OK"];
            }
        }
        
        if (posts.count > 0) {
            self.posts = posts;
            AwfulPost *anyPost = posts.lastObject;
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
        
        if (self.hiddenPosts == 0 && firstUnreadPost != NSNotFound) {
            self.hiddenPosts = firstUnreadPost;
        }
        
        if (reloadingSamePage || renderedCachedPosts) {
            _scrollToFractionAfterLoading = self.webView.awful_fractionalContentOffset;
        }
        
        [self renderPosts];
        
        [self updateUserInterface];
        
        AwfulPost *lastPost = self.posts.lastObject;
        if (self.thread.seenPosts < lastPost.threadIndex) {
            self.thread.seenPosts = lastPost.threadIndex;
        }
        
        [self clearLoadingMessage];
        [self.postsView.pullToRefreshView stopAnimating];
    }];
}

- (void)scrollPostToVisible:(AwfulPost*)topPost
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
    NSString *script = LoadJavaScriptResources(@[ @"zepto.min.js", @"common.js", @"posts-view.js" ], &error);
    if (!script) {
        NSLog(@"%s error loading scripts: %@", __PRETTY_FUNCTION__, error);
        return;
    }
    context[@"script"] = script;
    context[@"userInterfaceIdiom"] = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? @"ipad" : @"iphone";
    context[@"stylesheet"] = self.theme[@"postsViewCSS"];
    NSMutableArray *postViewModels = [NSMutableArray new];
    NSRange range = NSMakeRange(self.hiddenPosts, 0);
    if ((NSInteger)self.posts.count > self.hiddenPosts) {
        range.length = self.posts.count - self.hiddenPosts;
    }
    for (AwfulPost *post in [self.posts subarrayWithRange:range]) {
        [postViewModels addObject:[[AwfulPostViewModel alloc] initWithPost:post]];
    }
    context[@"posts"] = postViewModels;
    if (self.advertisementHTML.length) {
        context[@"advertisementHTML"] = self.advertisementHTML;
    }
    if (postViewModels.count > 0 && self.page > 0 && self.page >= self.numberOfPages) {
        context[@"endMessage"] = @"End of the thread";
    }
    int fontScalePercentage = [AwfulSettings settings].fontScale;
    if (fontScalePercentage != 100) {
        context[@"fontScalePercentage"] = @(fontScalePercentage);
    }
    context[@"loggedInUsername"] = [AwfulSettings settings].username;
    NSString *HTML = [GRMustacheTemplate renderObject:context fromResource:@"PostsView" bundle:nil error:&error];
    if (!HTML) {
        NSLog(@"%s error loading posts view HTML: %@", __PRETTY_FUNCTION__, error);
    }
    [self.webView loadHTMLString:HTML baseURL:[AwfulForumsClient client].baseURL];
}

- (void)loadBlankPage
{
    [self.webView loadHTMLString:@"" baseURL:nil];
}

- (AwfulTheme *)theme
{
    AwfulForum *forum = self.thread.forum;
    return forum.forumID.length > 0 ? [AwfulTheme currentThemeForForum:self.thread.forum] : [AwfulTheme currentTheme];
}

- (UIBarButtonItem *)composeItem
{
    if (_composeItem) return _composeItem;
    _composeItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCompose target:nil action:nil];
    __weak __typeof__(self) weakSelf = self;
    _composeItem.awful_actionBlock = ^(UIBarButtonItem *sender) {
        __typeof__(self) self = weakSelf;
        if (!self.replyViewController) {
            self.replyViewController = [[AwfulReplyViewController alloc] initWithThread:self.thread quotedText:nil];
            self.replyViewController.delegate = self;
            self.replyViewController.restorationIdentifier = @"Reply composition";
        }
        [self presentViewController:[self.replyViewController enclosingNavigationController] animated:YES completion:nil];
    };
    return _composeItem;
}

- (UIBarButtonItem *)settingsItem
{
    if (_settingsItem) return _settingsItem;
    _settingsItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"page-settings"]
                                                     style:UIBarButtonItemStylePlain
                                                    target:nil
                                                    action:nil];
    __weak __typeof__(self) weakSelf = self;
    _settingsItem.awful_actionBlock = ^(UIBarButtonItem *sender) {
        __typeof__(self) self = weakSelf;
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
    };
    return _settingsItem;
}

- (UIBarButtonItem *)backItem
{
    if (_backItem) return _backItem;
    _backItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"arrowleft"] style:UIBarButtonItemStylePlain target:nil action:nil];
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
    __weak __typeof__(self) weakSelf = self;
    _currentPageItem.awful_actionBlock = ^(UIBarButtonItem *sender) {
        __typeof__(self) self = weakSelf;
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
    };
    return _currentPageItem;
}

- (UIBarButtonItem *)forwardItem
{
    if (_forwardItem) return _forwardItem;
    _forwardItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"arrowright"]
                                                    style:UIBarButtonItemStylePlain
                                                   target:nil
                                                   action:nil];
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
    _actionsItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:nil action:nil];
    __weak __typeof__(self) weakSelf = self;
    _actionsItem.awful_actionBlock = ^(UIBarButtonItem *sender) {
        __typeof__(self) self = weakSelf;
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
            [UIPasteboard generalPasteboard].awful_URL = URL;
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
            [vote showFromBarButtonItem:sender animated:NO];
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
            [sheet presentInPopoverFromBarButtonItem:sender];
        } else {
            UINavigationController *navigationController = self.navigationController;
            [sheet presentFromView:self.view highlightingRegionReturnedByBlock:^(UIView *view) {
                UIToolbar *toolbar = navigationController.toolbar;
                return [view convertRect:toolbar.bounds fromView:toolbar];
            }];
        }
    };
    return _actionsItem;
}

- (void)settingsDidChange:(NSNotification *)note
{
    if (![self isViewLoaded]) return;
    
    NSString *settingKey = note.userInfo[AwfulSettingsDidChangeSettingKey];
    if ([settingKey isEqualToString:AwfulSettingsKeys.showAvatars]) {
        [_webViewJavaScriptBridge callHandler:@"showAvatars" data:@([AwfulSettings settings].showAvatars)];
    } else if ([settingKey isEqualToString:AwfulSettingsKeys.username]) {
        [_webViewJavaScriptBridge callHandler:@"highlightMentionUsername" data:[AwfulSettings settings].username];
    } else if ([settingKey isEqualToString:AwfulSettingsKeys.fontScale]) {
        [_webViewJavaScriptBridge callHandler:@"fontScale" data:@([AwfulSettings settings].fontScale)];
    } else if ([settingKey isEqualToString:AwfulSettingsKeys.showImages]) {
        if ([AwfulSettings settings].showImages) {
            [_webViewJavaScriptBridge callHandler:@"loadLinkifiedImages"];
        }
    }
}

- (void)themeDidChange
{
    [super themeDidChange];
    
    AwfulTheme *theme = self.theme;
    self.view.backgroundColor = theme[@"backgroundColor"];
    self.postsView.indicatorStyle = theme.scrollIndicatorStyle;
    [_webViewJavaScriptBridge callHandler:@"changeStylesheet" data:theme[@"postsViewCSS"]];
    
    if (self.loadingView) {
        [self.loadingView removeFromSuperview];
        self.loadingView = [AwfulLoadingView loadingViewForTheme:theme];
        [self.view addSubview:self.loadingView];
    }
    
    AwfulPageTopBar *topBar = self.topBar;
    topBar.backgroundColor = theme[@"postsTopBarBackgroundColor"];
    void (^configureButton)(UIButton *) = ^(UIButton *button){
        [button setTitleColor:theme[@"postsTopBarTextColor"] forState:UIControlStateNormal];
        [button setTitleColor:[UIColor lightGrayColor] forState:UIControlStateDisabled];
        button.backgroundColor = theme[@"postsTopBarBackgroundColor"];
    };
    configureButton(topBar.goToForumButton);
    configureButton(topBar.loadReadPostsButton);
    configureButton(topBar.scrollToBottomButton);
    
    [self.replyViewController themeDidChange];
    [self.messageViewController themeDidChange];
}

- (void)refetchPosts
{
    if (!self.thread || self.page < 1) return;
    
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:[AwfulPost entityName]];
    NSInteger lowIndex = (self.page - 1) * 40 + 1;
    NSInteger highIndex = self.page * 40;
    NSString *indexKey;
    if (self.author) {
        indexKey = @"singleUserIndex";
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
        [self setLoadingMessage:@"Loading…"];
    } else {
        [self clearLoadingMessage];
    }
    
    self.topBar.scrollToBottomButton.enabled = [self.posts count] > 0;
    self.topBar.loadReadPostsButton.enabled = self.hiddenPosts > 0;
    
    SVPullToRefreshView *refresh = self.postsView.pullToRefreshView;
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
    } else {
        self.currentPageItem.title = @"";
    }
    self.forwardItem.enabled = self.page > 0 && self.page < self.numberOfPages;
    self.composeItem.enabled = !self.thread.closed;
}

- (void)setLoadingMessage:(NSString *)message
{
    if (!self.loadingView) {
        self.loadingView = [AwfulLoadingView loadingViewForTheme:self.theme];
    }
    self.loadingView.message = message;
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
    AwfulThreadPage nextPage = self.numberOfPages > self.page ? self.page + 1 : self.page;
    [self loadPage:nextPage updatingCache:YES];
}

- (void)goToParentForum
{
    NSString *url = [NSString stringWithFormat:@"awful://forums/%@", self.thread.forum.forumID];
    [AwfulAppDelegate.instance openAwfulURL:[NSURL URLWithString:url]];
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
    UIScrollView *scrollView = self.postsView;
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
    [_webViewJavaScriptBridge callHandler:@"interestingElementsAtPoint" data:data responseCallback:^(NSDictionary *elementInfo) {
        if (elementInfo.count == 0) return;
        
        NSURL *imageURL = [NSURL URLWithString:elementInfo[@"spoiledImageURL"] relativeToURL:[AwfulForumsClient client].baseURL];
        if (elementInfo[@"spoiledLink"]) {
            NSDictionary *linkInfo = elementInfo[@"spoiledLink"];
            NSURL *URL = [NSURL URLWithString:linkInfo[@"URL"] relativeToURL:[AwfulForumsClient client].baseURL];
            AwfulActionSheet *sheet = [AwfulActionSheet actionSheetOpeningURL:URL fromViewController:self];
            sheet.title = URL.absoluteString;
            if (imageURL) {
                [sheet addButtonWithTitle:@"Show Image" block:^{
                    [self previewImageAtURL:imageURL];
                }];
            }
            CGRect rect = [self.webView awful_rectForElementBoundingRect:linkInfo[@"rect"]];
            [sheet showFromRect:rect inView:self.view animated:YES];
        } else if (imageURL) {
            [self previewImageAtURL:imageURL];
        } else if (elementInfo[@"spoiledVideo"]) {
            NSDictionary *videoInfo = elementInfo[@"spoiledVideo"];
            NSURL *URL = [NSURL URLWithString:videoInfo[@"URL"] relativeToURL:[AwfulForumsClient client].baseURL];
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
            
            void (^openInSafariOrYouTube)(void) = ^{ [[UIApplication sharedApplication] openURL:safariURL]; };
            if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"youtube://"]]) {
                [sheet addButtonWithTitle:@"Open in YouTube" block:openInSafariOrYouTube];
            } else {
                [sheet addButtonWithTitle:@"Open in Safari" block:openInSafariOrYouTube];
            }
            
            [sheet addCancelButtonWithTitle:@"Cancel"];
            
            CGRect rect = [self.webView awful_rectForElementBoundingRect:videoInfo[@"rect"]];
            [sheet showFromRect:rect inView:self.webView animated:YES];
        } else {
            NSLog(@"%s unexpected interesting elements: %@", __PRETTY_FUNCTION__, elementInfo);
        }
    }];
}

- (void)previewImageAtURL:(NSURL *)URL
{
    AwfulImagePreviewViewController *preview = [[AwfulImagePreviewViewController alloc] initWithURL:URL];
    preview.title = self.title;
    UINavigationController *nav = [preview enclosingNavigationController];
    nav.navigationBar.translucent = YES;
    [self presentViewController:nav animated:YES completion:nil];
}

- (NSString *)renderedPostAtIndex:(NSInteger)index
{
    AwfulPost *post = self.posts[index + self.hiddenPosts];
    AwfulPostViewModel *viewModel = [[AwfulPostViewModel alloc] initWithPost:post];
    NSError *error;
    NSString *HTML = [GRMustacheTemplate renderObject:viewModel fromResource:@"Post" bundle:nil error:&error];
    if (!HTML) {
        NSLog(@"error rendering post at index %@: %@", @(index), error);
    }
    return HTML;
}

- (void)readIgnoredPostAtIndex:(NSUInteger)index
{
    AwfulPost *post = self.posts[index];
    __weak __typeof__(self) weakSelf = self;
    [[AwfulForumsClient client] readIgnoredPost:post andThen:^(NSError *error) {
        __typeof__(self) self = weakSelf;
        if (error) {
            [AwfulAlertView showWithTitle:@"Network Error" error:error buttonTitle:@"OK"];
            return;
        }
        
        // Grabbing the index here ensures we're still on the same page as the post to replace, and that we have the right post index (in case it got hidden).
        NSInteger i = [self.posts indexOfObject:post];
        if (i > self.hiddenPosts && i != NSNotFound) {
            NSDictionary *data = @{ @"index": @(i),
                                    @"HTML": [self renderedPostAtIndex:index] };
            [_webViewJavaScriptBridge callHandler:@"postHTMLAtIndex" data:data];
        }
    }];
}

- (void)didTapUserHeaderWithRect:(CGRect)rect forPostAtIndex:(NSUInteger)postIndex
{
    AwfulPost *post = self.posts[postIndex + self.hiddenPosts];
    AwfulUser *user = post.author;
	AwfulActionViewController *sheet = [AwfulActionViewController new];
    
	[sheet addItem:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeUserProfile action:^{
        AwfulProfileViewController *profile = [[AwfulProfileViewController alloc] initWithUser:user];
        [self presentViewController:[profile enclosingNavigationController] animated:YES completion:nil];
	}]];
    
	if (!self.author) {
		[sheet addItem:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeSingleUsersPosts action:^{
            AwfulPostsViewController *postsView = [[AwfulPostsViewController alloc] initWithThread:self.thread author:user];
            [postsView loadPage:1 updatingCache:YES];
            [self.navigationController pushViewController:postsView animated:YES];
        }]];
	}
    
	if ([AwfulSettings settings].canSendPrivateMessages && user.canReceivePrivateMessages) {
        if (![user.userID isEqual:[AwfulSettings settings].userID]) {
            [sheet addItem:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeSendPrivateMessage action:^{
                self.messageViewController = [[AwfulNewPrivateMessageViewController alloc] initWithRecipient:user];
                self.messageViewController.delegate = self;
                self.messageViewController.restorationIdentifier = @"New PM from posts view";
                [self presentViewController:[self.messageViewController enclosingNavigationController] animated:YES completion:nil];
            }]];
        }
	}
    
	[sheet addItem:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeRapSheet action:^{
        AwfulRapSheetViewController *rapSheet = [[AwfulRapSheetViewController alloc] initWithUser:user];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            [self presentViewController:[rapSheet enclosingNavigationController] animated:YES completion:nil];
        } else {
            [self.navigationController pushViewController:rapSheet animated:YES];
        }
	}]];
    
    AwfulSemiModalRectInViewBlock headerRectBlock = ^(UIView *view) {
        NSString *rectString = [self.webView awful_evalJavaScript:@"HeaderRectForPostAtIndex(%lu, %@)", (unsigned long)postIndex, UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? @"true" : @"false"];
        return [self.webView awful_rectForElementBoundingRect:rectString];
    };
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [sheet presentInPopoverFromView:self.webView pointingToRegionReturnedByBlock:headerRectBlock];
    } else {
        [sheet presentFromView:self.webView highlightingRegionReturnedByBlock:headerRectBlock];
    }
}

- (void)didTapActionButtonWithRect:(CGRect)rect forPostAtIndex:(NSUInteger)postIndex
{
    NSAssert(postIndex + self.hiddenPosts < self.posts.count, @"post %lu beyond range (hiding %ld posts)", (unsigned long)postIndex, (long)self.hiddenPosts);
    
    AwfulPost *post = self.posts[postIndex + self.hiddenPosts];
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
        [UIPasteboard generalPasteboard].awful_URL = URL;
    }]];
    
    if (!self.author) {
        [sheet addItem:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeMarkReadUpToHere action:^{
            [[AwfulForumsClient client] markThreadReadUpToPost:post andThen:^(NSError *error) {
                if (error) {
                    [AwfulAlertView showWithTitle:@"Could Not Mark Read" error:error buttonTitle:@"Alright"];
                } else {
                    post.thread.seenPosts = post.threadIndex;
                    [_webViewJavaScriptBridge callHandler:@"markReadUpToPostWithID" data:post.postID];
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
        [sheet presentInPopoverFromView:self.webView pointingToRegionReturnedByBlock:^(UIView *view) {
            NSString *rectString = [self.webView awful_evalJavaScript:@"ActionButtonRectForPostAtIndex(%lu)", (unsigned long)postIndex];
            return [self.webView awful_rectForElementBoundingRect:rectString];
        }];
    } else {
        [sheet presentFromView:self.webView highlightingRegionReturnedByBlock:^(UIView *view) {
            NSString *rectString = [self.webView awful_evalJavaScript:@"FooterRectForPostAtIndex(%lu)", (unsigned long)postIndex];
            return [self.webView awful_rectForElementBoundingRect:rectString];
        }];
    }
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
    UIWebView *webView = [UIWebView awful_nativeFeelingWebView];
    webView.backgroundColor = nil;
    self.view = [[AwfulPostsView alloc] initWithWebView:webView];
    
    self.topBar = [AwfulPageTopBar new];
    self.topBar.frame = CGRectMake(0, -40, CGRectGetWidth(self.view.frame), 40);
    [self.topBar.goToForumButton addTarget:self action:@selector(goToParentForum)
                          forControlEvents:UIControlEventTouchUpInside];
    [self.topBar.loadReadPostsButton addTarget:self action:@selector(showHiddenSeenPosts)
                              forControlEvents:UIControlEventTouchUpInside];
    self.topBar.loadReadPostsButton.enabled = self.hiddenPosts > 0;
    [self.topBar.scrollToBottomButton addTarget:self action:@selector(scrollToBottom)
                               forControlEvents:UIControlEventTouchUpInside];
    [self.postsView addSubview:self.topBar];
    self.postsView.delegate = self.topBar;
    
    NSArray *buttons = @[ self.topBar.goToForumButton, self.topBar.loadReadPostsButton, self.topBar.scrollToBottomButton ];
    for (UIButton *button in buttons) {
        [button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        [button setTitleShadowColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [button setTitleColor:[UIColor lightGrayColor] forState:UIControlStateDisabled];
        button.backgroundColor = [UIColor colorWithRed:0.973 green:0.973 blue:0.973 alpha:1];
    }
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
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // Doing this here avoids SVPullToRefresh's poor interaction with automaticallyAdjustsScrollViewInsets.
    __weak __typeof__(self) weakSelf = self;
    [self.postsView addPullToRefreshWithActionHandler:^{
        __typeof__(self) self = weakSelf;
        [self loadNextPageOrRefresh];
    } position:SVPullToRefreshPositionBottom];
}

- (void)viewDidDisappear:(BOOL)animated
{    
    // Blank the web view if we're leaving for good. Otherwise we get weirdness like videos continuing to play their sound after the user switches to a different thread.
    if (!self.navigationController) {
        [self loadBlankPage];
    }
    [super viewDidDisappear:animated];
}

#pragma mark - AwfulComposeTextViewControllerDelegate

- (void)composeTextViewController:(AwfulComposeTextViewController *)composeTextViewController
didFinishWithSuccessfulSubmission:(BOOL)success
                  shouldKeepDraft:(BOOL)keepDraft
{
    [self dismissViewControllerAnimated:YES completion:^{
        if (composeTextViewController == self.replyViewController) {
            if (success) {
                if (self.replyViewController.thread) {
                    [self loadPage:AwfulThreadPageNextUnread updatingCache:YES];
                } else {
                    AwfulPost *post = self.replyViewController.post;
                    if (self.author) {
                        [self loadPage:post.singleUserPage updatingCache:YES];
                    } else {
                        [self loadPage:post.page updatingCache:YES];
                    }
                    [self scrollPostToVisible:self.replyViewController.post];
                }
            }
            if (!keepDraft) {
                self.replyViewController = nil;
            }
        }
    }];
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
            [AwfulBrowserViewController presentBrowserForURL:URL fromViewController:self];
        } else {
            [[UIApplication sharedApplication] openURL:URL];
        }
        return NO;
    }
    
    return YES;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    if (!_webViewDidLoadOnce) {
        _webViewDidLoadOnce = YES;
        if (_jumpToPostIDAfterLoading) {
            [_webViewJavaScriptBridge callHandler:@"jumpToPostWithID" data:_jumpToPostIDAfterLoading];
        } else if (_scrollToFractionAfterLoading > 0) {
            webView.awful_fractionalContentOffset = _scrollToFractionAfterLoading;
        }
        _jumpToPostIDAfterLoading = nil;
        _scrollToFractionAfterLoading = 0;
    }
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
    [coder encodeFloat:self.webView.awful_fractionalContentOffset forKey:ScrolledFractionOfContentKey];
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
    _restoringState = YES;
    [super decodeRestorableStateWithCoder:coder];
    self.replyViewController = [coder decodeObjectForKey:ReplyViewControllerKey];
    self.replyViewController.delegate = self;
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
}

- (void)applicationFinishedRestoringState
{
    _restoringState = NO;
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
