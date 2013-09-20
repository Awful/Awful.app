//  AwfulPostsViewController.m
//
//  Copyright 2010 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPostsViewController.h"
#import "AwfulActionSheet.h"
#import "AwfulAlertView.h"
#import "AwfulAppDelegate.h"
#import "AwfulBrowserViewController.h"
#import "AwfulDataStack.h"
#import "AwfulDateFormatters.h"
#import "AwfulExternalBrowser.h"
#import "AwfulHTTPClient.h"
#import "AwfulIconActionSheet.h"
#import "AwfulImagePreviewViewController.h"
#import "AwfulJumpToPageController.h"
#import "AwfulLoadingView.h"
#import "AwfulModels.h"
#import "AwfulPageBottomBar.h"
#import "AwfulPageTopBar.h"
#import "AwfulPlainBarButtonItem.h"
#import "AwfulPopoverController.h"
#import "AwfulPostsView.h"
#import "AwfulPostsViewSettingsController.h"
#import "AwfulPostViewModel.h"
#import "AwfulProfileViewController.h"
#import "AwfulPrivateMessageComposeViewController.h"
#import "AwfulPullToRefreshControl.h"
#import "AwfulRapSheetViewController.h"
#import "AwfulReadLaterService.h"
#import "AwfulReplyComposeViewController.h"
#import "AwfulSettings.h"
#import "AwfulTheme.h"
#import "AwfulThemingViewController.h"
#import <GRMustache/GRMustache.h>
#import "NSFileManager+UserDirectories.h"
#import "NSManagedObject+Awful.h"
#import "NSString+CollapseWhitespace.h"
#import "NSURL+Awful.h"
#import "NSURL+OpensInBrowser.h"
#import "NSURL+Punycode.h"
#import "NSURL+QueryDictionary.h"
#import <SVProgressHUD/SVProgressHUD.h>
#import "UIDevice+OperatingSystemVersion.h"
#import "UINavigationItem+TwoLineTitle.h"
#import "UIViewController+NavigationEnclosure.h"

@interface AwfulPostsViewController () <AwfulPostsViewDelegate,
                                        AwfulJumpToPageControllerDelegate,
                                        NSFetchedResultsControllerDelegate,
                                        AwfulReplyComposeViewControllerDelegate,
                                        UIScrollViewDelegate,
                                        AwfulThemingViewController,
                                        AwfulPrivateMessageComposeViewControllerDelegate,
                                        AwfulPostsViewSettingsControllerDelegate,
                                        AwfulPopoverControllerDelegate>

@property (nonatomic) AwfulThreadPage currentPage;

@property (nonatomic) NSFetchedResultsController *fetchedResultsController;

@property (weak, nonatomic) NSOperation *networkOperation;

@property (nonatomic) AwfulPageTopBar *topBar;
@property (nonatomic) AwfulPostsView *postsView;
@property (nonatomic) AwfulPageBottomBar *bottomBar;
@property (nonatomic) AwfulPopoverController *jumpToPagePopover;
@property (nonatomic) AwfulPullToRefreshControl *pullUpToRefreshControl;
@property (nonatomic) UIBarButtonItem *composeItem;
@property (copy, nonatomic) NSString *ongoingReplyText;
@property (nonatomic) id ongoingReplyImageCacheIdentifier;
@property (nonatomic) AwfulPost *ongoingEditedPost;
@property (nonatomic) AwfulPostsViewSettingsController *settingsViewController;

@property (nonatomic) NSInteger hiddenPosts;
@property (copy, nonatomic) NSString *jumpToPostAfterLoad;
@property (copy, nonatomic) NSString *advertisementHTML;
@property (nonatomic) GRMustacheTemplate *postTemplate;
@property (nonatomic) AwfulLoadingView *loadingView;

@property (nonatomic) BOOL observingScrollViewSize;
@property (nonatomic) BOOL observingThreadSeenPosts;

@property (nonatomic) NSMutableArray *cachedUpdatesWhileScrolling;

@end


@implementation AwfulPostsViewController

- (id)init
{
    if (!(self = [super initWithNibName:nil bundle:nil])) return nil;
    self.hidesBottomBarWhenPushed = YES;
    self.navigationItem.rightBarButtonItem = self.composeItem;
    NSNotificationCenter *noteCenter = [NSNotificationCenter defaultCenter];
    [noteCenter addObserver:self selector:@selector(settingChanged:)
                       name:AwfulSettingsDidChangeNotification object:nil];
    [noteCenter addObserver:self selector:@selector(willResetDataStack:)
                       name:AwfulDataStackWillResetNotification object:nil];
    return self;
}

- (UIBarButtonItem *)composeItem
{
    if (_composeItem) return _composeItem;
    _composeItem = [[AwfulPlainBarButtonItem alloc]
                    initWithBarButtonSystemItem:UIBarButtonSystemItemCompose
                    target:self action:@selector(didTapCompose)];
    return _composeItem;
}

- (void)didTapCompose
{
    AwfulReplyComposeViewController *reply = [AwfulReplyComposeViewController new];
    reply.delegate = self;
    if (self.ongoingEditedPost) {
        [reply editPost:self.ongoingEditedPost
                   text:self.ongoingReplyText
   imageCacheIdentifier:self.ongoingReplyImageCacheIdentifier];
    } else {
        [reply replyToThread:self.thread
         withInitialContents:self.ongoingReplyText
        imageCacheIdentifier:self.ongoingReplyImageCacheIdentifier];
    }
    [self presentViewController:[reply enclosingNavigationController] animated:YES completion:nil];
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
        AwfulSettingsKeys.fontSize,
    ];
    NSArray *keys = note.userInfo[AwfulSettingsDidChangeSettingsKey];
    if ([keys firstObjectCommonWithArray:importantKeys]) {
        return [self configurePostsViewSettings];
    }
    NSString *themeKey = nil;
    if ([self.thread.forum.forumID isEqualToString:@"219"]) {
        themeKey = AwfulSettingsKeys.yosposStyle;
    } else if ([self.thread.forum.forumID isEqualToString:@"25"]) {
        themeKey = AwfulSettingsKeys.gasChamberStyle;
    } else if ([self.thread.forum.forumID isEqualToString:@"26"]) {
        themeKey = AwfulSettingsKeys.fyadStyle;
    }
    if (themeKey && [keys containsObject:themeKey]) {
        [self configurePostsViewSettings];
    }
}

- (void)willResetDataStack:(NSNotification *)note
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
    [self deleteReplyImageCacheInBackground];
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
    [self forgetOngoingReply];
}

- (void)forgetOngoingReply
{
    self.ongoingReplyText = nil;
    [self deleteReplyImageCacheInBackground];
    self.ongoingEditedPost = nil;
}

- (void)deleteReplyImageCacheInBackground
{
    NSString *imageCacheIdentifier = self.ongoingReplyImageCacheIdentifier;
    if (!imageCacheIdentifier) return;
    self.ongoingReplyImageCacheIdentifier = nil;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [AwfulReplyComposeViewController deleteImageCacheWithIdentifier:imageCacheIdentifier];
    });
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
    }
    NSInteger lowIndex = (self.currentPage - 1) * 40 + 1;
    NSInteger highIndex = self.currentPage * 40;
    NSString *indexKey;
    if (self.singleUserID) {
        indexKey = AwfulPostAttributes.singleUserIndex;
    } else {
        indexKey = AwfulPostAttributes.threadIndex;
    }
    request.predicate = [NSPredicate predicateWithFormat:
                         @"thread = %@ AND %d <= %K AND %K <= %d",
                         self.thread, lowIndex, indexKey, indexKey, highIndex];
    if (self.singleUserID) {
        NSPredicate *and = [NSPredicate predicateWithFormat:
                            @"author.userID = %@", self.singleUserID];
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
    
    if (self.currentPage == AwfulThreadPageLast ||
        self.currentPage == AwfulThreadPageNextUnread ||
        [self.fetchedResultsController.fetchedObjects count] == 0)
    {
        [self setLoadingMessage:@"Loading…"];
    } else {
        [self clearLoadingMessage];
    }
    
    self.topBar.scrollToBottomButton.enabled = [self.posts count] > 0;
    self.topBar.loadReadPostsButton.enabled = self.hiddenPosts > 0;
    
    NSInteger relevantNumberOfPages = [self relevantNumberOfPagesInThread];
    if (self.currentPage > 0 && self.currentPage >= relevantNumberOfPages) {
        self.postsView.endMessage = @"End of the thread";
    } else {
        self.postsView.endMessage = nil;
    }
    
    AwfulPullToRefreshControl *refresh = self.pullUpToRefreshControl;
    if (relevantNumberOfPages > self.currentPage) {
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
    if (self.currentPage > 0 && self.currentPage < relevantNumberOfPages) {
        [self.bottomBar.backForwardControl setEnabled:YES forSegmentAtIndex:1];
    } else {
        [self.bottomBar.backForwardControl setEnabled:NO forSegmentAtIndex:1];
    }
    if (self.currentPage > 0 && relevantNumberOfPages > 0) {
        [self.bottomBar.jumpToPageButton setTitle:[NSString stringWithFormat:@"Page %d of %d",
                                                   self.currentPage, relevantNumberOfPages]
                                         forState:UIControlStateNormal];
    } else {
        [self.bottomBar.jumpToPageButton setTitle:@"" forState:UIControlStateNormal];
    }
    self.composeItem.enabled = !self.thread.isClosedValue;
}

- (void)setLoadingMessage:(NSString *)message
{
    if (!self.loadingView) {
        AwfulLoadingViewType loadingViewType = AwfulLoadingViewTypeDefault;
        UIColor *tintColor = [AwfulTheme currentTheme].postsViewBackgroundColor;
        if ([self.thread.forum.forumID isEqualToString:@"25"]) {
            if ([AwfulSettings settings].gasChamberStyle == AwfulGasChamberStyleSickly) {
                loadingViewType = AwfulLoadingViewTypeGasChamber;
            }
        } else if ([self.thread.forum.forumID isEqualToString:@"26"]) {
            if ([AwfulSettings settings].fyadStyle == AwfulFYADStylePink) {
                loadingViewType = AwfulLoadingViewTypeFYAD;
            }
        } else if ([self.thread.forum.forumID isEqualToString:@"219"]) {
            switch ([AwfulSettings settings].yosposStyle) {
                case AwfulYOSPOSStyleAmber:
                    loadingViewType = AwfulLoadingViewTypeYOSPOS;
                    tintColor = [UIColor colorWithRed:0.918 green:0.812 blue:0.298 alpha:1];
                    break;
                case AwfulYOSPOSStyleGreen:
                    loadingViewType = AwfulLoadingViewTypeYOSPOS;
                    tintColor = [UIColor colorWithRed:0.373 green:0.992 blue:0.38 alpha:1];
                    break;
                case AwfulYOSPOSStyleMacinyos:
                    loadingViewType = AwfulLoadingViewTypeMacinyos;
                    break;
                case AwfulYOSPOSStyleWinpos95:
                    loadingViewType = AwfulLoadingViewTypeWinpos95;
                    break;
                default:
                    break;
            }
        }
        self.loadingView = [AwfulLoadingView loadingViewWithType:loadingViewType];
        if (tintColor) self.loadingView.tintColor = tintColor;
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
    self.postsView.showAvatars = [AwfulSettings settings].showAvatars;
    self.postsView.showImages = [AwfulSettings settings].showImages;
    self.postsView.fontSize = [AwfulSettings settings].fontSize;
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
    if (self.loadingView) {
        NSString *message = self.loadingView.message;
        [self clearLoadingMessage];
        [self setLoadingMessage:message];
    }
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

- (void)loadPage:(AwfulThreadPage)page singleUserID:(NSString *)singleUserID
{
    [self stopObservingThreadSeenPosts];
    [self.networkOperation cancel];
    self.jumpToPostAfterLoad = nil;
    NSInteger oldPage = self.currentPage;
    self.currentPage = page;
    BOOL refreshingSamePage = page > 0 && page == oldPage;
    if (!refreshingSamePage ||
        (singleUserID != self.singleUserID && [singleUserID isEqual:self.singleUserID])) {
        self.singleUserID = singleUserID;
        self.cachedUpdatesWhileScrolling = nil;
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
                                                 singleUserID:singleUserID
                                                      andThen:^(NSError *error, NSArray *posts,
                                                                NSUInteger firstUnreadPost,
                                                                NSString *advertisementHTML)
    {
        // Since we load cached pages where possible, things can get out of order if we change
        // pages quickly. If the callback comes in after we've moved away from the requested page,
        // just don't bother going any further. We have the data for later.
        if (page != self.currentPage) return;
        BOOL wasLoading = !!self.loadingView;
        if (error) {
            if (wasLoading) {
                [self clearLoadingMessage];
                if (![[self.bottomBar.jumpToPageButton titleForState:UIControlStateNormal] length]) {
                    if ([self relevantNumberOfPagesInThread] > 0) {
                        NSString *title = [NSString stringWithFormat:@"Page ? of %d",
                                           [self relevantNumberOfPagesInThread]];
                        [self.bottomBar.jumpToPageButton setTitle:title
                                                       forState:UIControlStateNormal];
                    } else {
                        [self.bottomBar.jumpToPageButton setTitle:@"Page ? of ?"
                                                       forState:UIControlStateNormal];
                    }
                }
            }
            // Poor man's offline mode.
            if (!wasLoading && !refreshingSamePage)
            if ([error.domain isEqualToString:NSURLErrorDomain]) {
                return;
            }
            [AwfulAlertView showWithTitle:@"Could Not Load Page" error:error buttonTitle:@"OK"];
            self.pullUpToRefreshControl.refreshing = NO;
            return;
        }
        AwfulPost *lastPost = [posts lastObject];
        if (lastPost) {
            self.thread = [lastPost thread];
            self.currentPage = singleUserID ? lastPost.singleUserPage : lastPost.page;
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
        if (self.jumpToPostAfterLoad) {
            [self jumpToPostWithID:self.jumpToPostAfterLoad];
            self.jumpToPostAfterLoad = nil;
        } else if (wasLoading) {
            if (self.hiddenPosts > 0) {
                [self.postsView.scrollView setContentOffset:CGPointZero animated:NO];
            } else {
                CGFloat inset = self.postsView.scrollView.contentInset.top;
                [self.postsView.scrollView setContentOffset:CGPointMake(0, -inset) animated:NO];
            }
        }
        [self updateUserInterface];
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
    if (self.loadingView) {
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
    if ([self relevantNumberOfPagesInThread] > self.currentPage) {
        [self loadPage:self.currentPage + 1 singleUserID:self.singleUserID];
    } else {
        [self loadPage:self.currentPage singleUserID:self.singleUserID];
    }
}

- (void)showThreadActionsFromRect:(CGRect)rect inView:(UIView *)view
{
    AwfulIconActionSheet *sheet = [AwfulIconActionSheet new];
    sheet.title = self.title;
    AwfulIconActionItem *copyURL = [AwfulIconActionItem itemWithType:AwfulIconActionItemTypeCopyURL
                                                              action:^{
        NSString *url = [NSString stringWithFormat:@"http://forums.somethingawful.com/"
                         "showthread.php?threadid=%@&perpage=40&pagenumber=%@",
                         self.thread.threadID, @(self.currentPage)];
        [AwfulSettings settings].lastOfferedPasteboardURL = url;
        [UIPasteboard generalPasteboard].items = @[ @{
                                                        (id)kUTTypeURL: [NSURL URLWithString:url],
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
        [vote showFromRect:rect inView:view animated:YES];
    }]];
    
    AwfulIconActionItemType bookmarkItemType;
    if (self.thread.isBookmarkedValue) {
        bookmarkItemType = AwfulIconActionItemTypeRemoveBookmark;
    } else {
        bookmarkItemType = AwfulIconActionItemTypeAddBookmark;
    }
    [sheet addItem:[AwfulIconActionItem itemWithType:bookmarkItemType action:^{
        [[AwfulHTTPClient client] setThreadWithID:self.thread.threadID
                                     isBookmarked:!self.thread.isBookmarkedValue
                                          andThen:^(NSError *error)
         {
             if (error) {
                 NSLog(@"error %@bookmarking thread %@: %@",
                       self.thread.isBookmarkedValue ? @"un" : @"", self.thread.threadID, error);
             } else {
                 NSString *status = @"Removed Bookmark";
                 if (self.thread.isBookmarkedValue) {
                     status = @"Added Bookmark";
                 }
                 [SVProgressHUD showSuccessWithStatus:status];
             }
         }];
    }]];
    [sheet presentFromViewController:self fromRect:rect inView:view];
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
        [self presentViewController:[profile enclosingNavigationController]
                           animated:YES completion:nil];
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

- (void)showRapSheetWithUser:(AwfulUser *)user
{
    AwfulRapSheetViewController *rapSheet = [AwfulRapSheetViewController new];
    rapSheet.userID = user.userID;
    UIBarButtonItem *item;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        item = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                             target:nil
                                                             action:@selector(doneWithRapSheet)];
        rapSheet.navigationItem.leftBarButtonItem = item;
        [self presentViewController:[rapSheet enclosingNavigationController]
                           animated:YES completion:nil];
    } else {
        rapSheet.hidesBottomBarWhenPushed = YES;
        item = [[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStyleBordered
                                               target:nil action:NULL];
        self.navigationItem.backBarButtonItem = item;
        [self.navigationController pushViewController:rapSheet animated:YES];
    }
}

- (void)doneWithRapSheet
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
    if (self.loadingView) {
        NSString *message = self.loadingView.message;
        [self clearLoadingMessage];
        [self setLoadingMessage:message];
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
    self.view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    CGRect postsFrame, pageBarFrame;
    CGRectDivide(self.view.bounds, &pageBarFrame, &postsFrame, 38, CGRectMaxYEdge);
    
    AwfulPageBottomBar *pageBar = [[AwfulPageBottomBar alloc] initWithFrame:pageBarFrame];
    [pageBar.backForwardControl addTarget:self
                                   action:@selector(didTapPreviousNextPageControl:)
                         forControlEvents:UIControlEventValueChanged];
    [pageBar.jumpToPageButton addTarget:self
                                 action:@selector(showJumpToPageSheet)
                       forControlEvents:UIControlEventTouchUpInside];
    [pageBar.actionsFontSizeControl addTarget:self
                                       action:@selector(didTapActionFontSizeControl:)
                             forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:pageBar];
    self.bottomBar = pageBar;
    
    self.postsView = [[AwfulPostsView alloc] initWithFrame:postsFrame];
    self.postsView.delegate = self;
    self.postsView.scrollView.delegate = self;
    self.postsView.autoresizingMask = (UIViewAutoresizingFlexibleWidth |
                                       UIViewAutoresizingFlexibleHeight);
    self.postsView.backgroundColor = self.view.backgroundColor;
    [self.view addSubview:self.postsView];
    [self configurePostsViewSettings];
    
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
    
    self.pullUpToRefreshControl = [[AwfulPullToRefreshControl alloc]
                                   initWithDirection:AwfulScrollViewPullUp];
    [self.pullUpToRefreshControl addTarget:self action:@selector(loadNextPageOrRefresh)
                          forControlEvents:UIControlEventValueChanged];
    self.pullUpToRefreshControl.backgroundColor = self.postsView.backgroundColor;
    [self.postsView.scrollView addSubview:self.pullUpToRefreshControl];
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
            self.pullUpToRefreshControl.triggerOffset = -10;
        }
    }
}

- (void)didTapPreviousNextPageControl:(UISegmentedControl *)seg
{
    if (seg.selectedSegmentIndex == 0) {
        if (self.currentPage > 1) {
            [self loadPage:self.currentPage - 1 singleUserID:self.singleUserID];
        }
    } else if (seg.selectedSegmentIndex == 1) {
        if (self.currentPage < [self relevantNumberOfPagesInThread]) {
            [self loadPage:self.currentPage + 1 singleUserID:self.singleUserID];
        }
    }
    seg.selectedSegmentIndex = UISegmentedControlNoSegment;
}

- (NSInteger)relevantNumberOfPagesInThread
{
    if (self.singleUserID) {
        return [self.thread numberOfPagesForSingleUser:
                [AwfulUser firstMatchingPredicate:@"userID = %@", self.singleUserID]];
    } else {
        return self.thread.numberOfPagesValue;
    }
}

- (void)showJumpToPageSheet
{
    if (self.loadingView) return;
    if (!self.jumpToPagePopover) {
        NSInteger relevantNumberOfPages = [self relevantNumberOfPagesInThread];
        if (relevantNumberOfPages < 1) return;
        AwfulJumpToPageController *jump = [[AwfulJumpToPageController alloc] initWithDelegate:self];
        jump.numberOfPages = relevantNumberOfPages;
        if (self.currentPage > 0) {
            jump.selectedPage = self.currentPage;
        }
        else if (self.currentPage == AwfulThreadPageLast && relevantNumberOfPages > 0) {
            jump.selectedPage = relevantNumberOfPages;
        }
        self.jumpToPagePopover = [[AwfulPopoverController alloc]
                                  initWithContentViewController:jump];
        self.jumpToPagePopover.delegate = self;
    }
    CGRect rect = [self.view convertRect:self.bottomBar.jumpToPageButton.bounds
                                fromView:self.bottomBar.jumpToPageButton];
    [self.jumpToPagePopover presentPopoverFromRect:rect inView:self.view animated:NO];
}

- (void)didTapActionFontSizeControl:(UISegmentedControl *)seg
{
    CGRect rect = seg.bounds;
    rect.size.width /= 2;
    rect.origin.x += CGRectGetWidth(rect) * seg.selectedSegmentIndex;
    UIView *inView = seg;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        inView = self.bottomBar;
        rect = inView.bounds;
    }
    if (seg.selectedSegmentIndex == 0) {
        [self showThreadActionsFromRect:rect inView:inView];
    } else if (seg.selectedSegmentIndex == 1) {
        if (self.settingsViewController) {
            [self.settingsViewController dismiss];
            self.settingsViewController = nil;
        } else {
            self.settingsViewController = [AwfulPostsViewSettingsController new];
            self.settingsViewController.delegate = self;
            if ([self.thread.forum.forumID isEqualToString:@"25"]) {
                self.settingsViewController.availableThemes = AwfulPostsViewSettingsControllerThemesGasChamber;
            } else if ([self.thread.forum.forumID isEqualToString:@"26"]) {
                self.settingsViewController.availableThemes = AwfulPostsViewSettingsControllerThemesFYAD;
            } else if ([self.thread.forum.forumID isEqualToString:@"219"]) {
                self.settingsViewController.availableThemes = AwfulPostsViewSettingsControllerThemesYOSPOS;
            }
            [self.settingsViewController presentFromViewController:self
                                                          fromRect:rect
                                                            inView:inView];
        }
    }
    seg.selectedSegmentIndex = UISegmentedControlNoSegment;
}

- (void)goToParentForum
{
    NSString *url = [NSString stringWithFormat:@"awful://forums/%@", self.thread.forum.forumID];
    [[AwfulAppDelegate instance] openAwfulURL:[NSURL URLWithString:url]];
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
    if (_observingScrollViewSize && [self isViewLoaded]) {
        [self.postsView.scrollView removeObserver:self
                                       forKeyPath:@"contentSize"
                                          context:&KVOContext];
        _observingScrollViewSize = NO;
    }
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                duration:(NSTimeInterval)duration
{
    [self.jumpToPagePopover dismissPopoverAnimated:NO];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                         duration:(NSTimeInterval)duration
{
    [self updatePullUpTriggerOffset];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    if (self.jumpToPagePopover) {
        [self showJumpToPageSheet];
    }
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
    browser.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:browser animated:YES];
    UIBarButtonItem *back = [[UIBarButtonItem alloc] initWithTitle:@"Back"
                                                             style:UIBarButtonItemStyleBordered
                                                            target:nil
                                                            action:NULL];
    self.navigationItem.backBarButtonItem = back;
}

- (void)postsView:(AwfulPostsView *)postsView didReceiveSingleTapAtPoint:(CGPoint)point
{
    CGRect rect;
    NSInteger postIndex = [postsView indexOfPostWithActionButtonAtPoint:point rect:&rect];
    if (postIndex == NSNotFound) return;
    AwfulPost *post = self.fetchedResultsController.fetchedObjects[postIndex + self.hiddenPosts];
    [self showActionsForPost:post fromRect:rect];
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
                         self.thread.threadID, @(self.currentPage), post.postID];
        [AwfulSettings settings].lastOfferedPasteboardURL = url;
        [UIPasteboard generalPasteboard].items = @[ @{
            (id)kUTTypeURL: [NSURL URLWithString:url],
            (id)kUTTypePlainText: url,
        }];
    }]];
    [sheet addItem:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeUserProfile action:^{
        [self showProfileWithUser:post.author];
    }]];
    if (!self.singleUserID) {
        [sheet addItem:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeMarkReadUpToHere
                                                  action:^
        {
            [[AwfulHTTPClient client] markThreadWithID:self.thread.threadID
                                   readUpToPostAtIndex:[post.threadIndex stringValue]
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
        }]];
        [sheet addItem:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeSingleUsersPosts
                                                  action:^
        {
            AwfulPostsViewController *postsView = [AwfulPostsViewController new];
            postsView.thread = self.thread;
            [postsView loadPage:1 singleUserID:post.author.userID];
            [self.navigationController pushViewController:postsView animated:YES];
        }]];
    }
    if (post.editableValue) {
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
                 [self forgetOngoingReply];
                 AwfulReplyComposeViewController *reply = [AwfulReplyComposeViewController new];
                 reply.delegate = self;
                 [reply editPost:post text:text imageCacheIdentifier:nil];
                 [self presentViewController:[reply enclosingNavigationController]
                                    animated:YES completion:nil];
             }];
        }]];
    }
    if (!self.thread.isClosedValue) {
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
                 NSMutableString *contents = [NSMutableString stringWithString:self.ongoingReplyText ?: @""];
                 while (contents.length > 0 && ![contents hasSuffix:@"\n\n"]) {
                     [contents appendString:@"\n"];
                 }
                 [contents appendString:quotedText];
                 AwfulReplyComposeViewController *reply = [AwfulReplyComposeViewController new];
                 reply.delegate = self;
                 if (self.ongoingEditedPost) {
                     [reply editPost:self.ongoingEditedPost
                                text:contents
                imageCacheIdentifier:self.ongoingReplyImageCacheIdentifier];
                 } else {
                     [reply replyToThread:self.thread
                      withInitialContents:contents
                     imageCacheIdentifier:self.ongoingReplyImageCacheIdentifier];
                 }
                 [self presentViewController:[reply enclosingNavigationController]
                                    animated:YES completion:nil];
             }];
        }]];
    }
    if ([AwfulSettings settings].canSendPrivateMessages &&
        post.author.canReceivePrivateMessagesValue &&
        ![post.author.userID isEqual:[AwfulSettings settings].userID]) {
        [sheet addItem:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeSendPrivateMessage
                                                  action:^
        {
            AwfulPrivateMessageComposeViewController *compose;
            compose = [AwfulPrivateMessageComposeViewController new];
            compose.delegate = self;
            [compose setRecipient:post.author.username];
            [self presentViewController:[compose enclosingNavigationController]
                               animated:YES completion:nil];
        }]];
    }
    [sheet addItem:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeRapSheet action:^{
        [self showRapSheetWithUser:post.author];
    }]];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [sheet presentFromViewController:self fromRect:rect inView:self.postsView];
    } else {
        [sheet presentFromViewController:self fromRect:self.bottomBar.bounds inView:self.bottomBar];
    }
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
        NSString *openInSafariTitle = @"Open in Safari";
        if ([url.host hasSuffix:@"youtube-nocookie.com"]) {
            NSString *youtubeVideoID = url.lastPathComponent;
            safariURL = [NSURL URLWithString:[NSString stringWithFormat:
                                              @"http://www.youtube.com/watch?v=%@", youtubeVideoID]];
            if ([[UIDevice currentDevice] awful_iOS5]) {
                openInSafariTitle = @"Open in YouTube";
            }
        } else if ([url.host hasSuffix:@"player.vimeo.com"]) {
            NSString *vimeoVideoID = url.lastPathComponent;
            safariURL = [NSURL URLWithString:[NSString stringWithFormat:
                                              @"http://vimeo.com/%@", vimeoVideoID]];
        }
        if (!safariURL) return;
        AwfulActionSheet *sheet = [AwfulActionSheet new];
        [sheet addButtonWithTitle:openInSafariTitle block:^{
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
    [self.pullUpToRefreshControl setRefreshing:NO animated:YES];
    [self updateUserInterface];
}

#pragma mark - AwfulJumpToPageControllerDelegate

- (void)jumpToPageController:(AwfulJumpToPageController *)jump didSelectPage:(AwfulThreadPage)page
{
    if (page != AwfulThreadPageNone) {
        if (self.singleUserID && page == AwfulThreadPageLast) {
            page = [self.thread numberOfPagesForSingleUser:
                    [AwfulUser firstMatchingPredicate:@"userID = %@", self.singleUserID]];
        }
        [self loadPage:page singleUserID:self.singleUserID];
    }
    [self.jumpToPagePopover dismissPopoverAnimated:NO];
    self.jumpToPagePopover = nil;
}

#pragma mark - AwfulPopoverControllerDelegate

- (void)popoverControllerDidDismissPopover:(AwfulPopoverController *)popover
{
    self.jumpToPagePopover = nil;
}

#pragma mark - AwfulReplyComposeViewControllerDelegate

- (void)replyComposeController:(AwfulReplyComposeViewController *)controller
              didReplyToThread:(AwfulThread *)thread
{
    [self forgetOngoingReply];
    [self dismissViewControllerAnimated:YES completion:^{
        [self loadPage:AwfulThreadPageNextUnread singleUserID:nil];
    }];
}

- (void)replyComposeController:(AwfulReplyComposeViewController *)controller
                   didEditPost:(AwfulPost *)post
{
    [self forgetOngoingReply];
    [self dismissViewControllerAnimated:YES completion:^{
        [self loadPage:self.singleUserID ? post.singleUserPage : post.page
          singleUserID:self.singleUserID];
        [self jumpToPostWithID:post.postID];
    }];
}

- (void)replyComposeControllerDidCancel:(AwfulReplyComposeViewController *)controller
{
    self.ongoingReplyText = controller.textView.text;
    self.ongoingReplyImageCacheIdentifier = [controller imageCacheIdentifier];
    self.ongoingEditedPost = controller.editedPost;
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

#pragma mark - AwfulPrivateMessageComposeViewControllerDelegate

- (void)privateMessageComposeControllerDidSendMessage:(AwfulPrivateMessageComposeViewController *)controller
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)privateMessageComposeControllerDidCancel:(AwfulPrivateMessageComposeViewController *)controller
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - AwfulPostsViewSettingsControllerDelegate

- (void)userDidDismissPostsViewSettings:(AwfulPostsViewSettingsController *)settings
{
    self.settingsViewController = nil;
}

@end
