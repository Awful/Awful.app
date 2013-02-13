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
#import "AwfulExternalBrowser.h"
#import "AwfulHTTPClient.h"
#import "AwfulImagePreviewViewController.h"
#import "AwfulModels.h"
#import "AwfulPageBottomBar.h"
#import "AwfulPageTopBar.h"
#import "AwfulPostsView.h"
#import "AwfulProfileViewController.h"
#import "AwfulPullToRefreshControl.h"
#import "AwfulReplyViewController.h"
#import "AwfulSettings.h"
#import "AwfulJumpToPageController.h"
#import "AwfulTheme.h"
#import "NSFileManager+UserDirectories.h"
#import "NSManagedObject+Awful.h"
#import "NSString+CollapseWhitespace.h"
#import "NSURL+Awful.h"
#import "NSURL+OpensInBrowser.h"
#import "NSURL+QueryDictionary.h"
#import "SVProgressHUD.h"
#import "UINavigationItem+TwoLineTitle.h"
#import "UIViewController+NavigationEnclosure.h"

@interface AwfulPostsViewController () <AwfulPostsViewDelegate, UIPopoverControllerDelegate,
                                        AwfulJumpToPageControllerDelegate,
                                        NSFetchedResultsControllerDelegate,
                                        AwfulReplyViewControllerDelegate,
                                        UIScrollViewDelegate>

@property (nonatomic) AwfulThreadPage currentPage;

@property (nonatomic) NSFetchedResultsController *fetchedResultsController;

@property (nonatomic) NSInteger hiddenPosts;

@property (weak, nonatomic) NSOperation *networkOperation;

@property (weak, nonatomic) AwfulPageTopBar *topBar;
@property (weak, nonatomic) AwfulPostsView *postsView;
@property (weak, nonatomic) AwfulPageBottomBar *bottomBar;
@property (weak, nonatomic) AwfulPullToRefreshControl *pullUpToRefreshControl;

@property (nonatomic) AwfulJumpToPageController *jumpToPageController;
@property (weak, nonatomic) UIView *pageNavBackingView;

@property (copy, nonatomic) NSString *advertisementHTML;

@property (nonatomic) BOOL didJustMarkAsReadToHere;

- (void)showThreadActionsFromRect:(CGRect)rect inView:(UIView *)view;

- (void)showActionsForPost:(AwfulPost *)post fromRect:(CGRect)rect inView:(UIView *)view;

@property (nonatomic) NSDateFormatter *regDateFormatter;
@property (nonatomic) NSDateFormatter *postDateFormatter;
@property (nonatomic) NSDateFormatter *editDateFormatter;

@property (nonatomic) UIPopoverController *popover;

@property (nonatomic) BOOL observingScrollViewSize;
@property (nonatomic) BOOL observingThreadSeenPosts;

@property (nonatomic) NSMutableArray *cachedUpdatesWhileScrolling;

@property (copy, nonatomic) NSString *jumpToPostAfterLoad;

@end


@implementation AwfulPostsViewController

- (id)init
{
    if (!(self = [super initWithNibName:nil bundle:nil])) return nil;
    self.hidesBottomBarWhenPushed = YES;
    NSNotificationCenter *noteCenter = [NSNotificationCenter defaultCenter];
    [noteCenter addObserver:self selector:@selector(currentThemeChanged:)
                       name:AwfulThemeDidChangeNotification object:nil];
    [noteCenter addObserver:self selector:@selector(settingChanged:)
                       name:AwfulSettingsDidChangeNotification object:nil];
    [noteCenter addObserver:self selector:@selector(didResetDataStack:)
                       name:AwfulDataStackDidResetNotification object:nil];
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopObserving];
    self.postsView.scrollView.delegate = nil;
    self.fetchedResultsController.delegate = nil;
    [self stopObservingThreadSeenPosts];
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

- (void)didResetDataStack:(NSNotification *)note
{
    self.fetchedResultsController = nil;
}

- (void)setThread:(AwfulThread *)thread
{
    if ([_thread isEqual:thread]) return;
    [self willChangeValueForKey:@"thread"];
    _thread = thread;
    [self didChangeValueForKey:@"thread"];
    self.title = [thread.title stringByCollapsingWhitespace];
    [self updatePageBar];
    [self configurePostsViewSettings];
    [self updateFetchedResultsController];
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
            else if (style == AwfulYOSPOSStyleMacinyos) filename = @"posts-view-219-macinyos.css";
            else if (style == AwfulYOSPOSStyleWinpos95) filename = @"posts-view-219-winpos95.css";
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

static char KVOContext;

- (void)stopObservingThreadSeenPosts
{
    if (self.observingThreadSeenPosts) {
        [self removeObserver:self forKeyPath:@"thread.seenPosts" context:&KVOContext];
    }
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

- (void)markPostsAsBeenSeenUpToPost:(AwfulPost *)post
{
    post.thread.seenPosts = post.threadIndex;
    [[AwfulDataStack sharedDataStack] save];
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
    [self.bottomBar.actionsComposeControl setEnabled:!self.thread.isClosedValue forSegmentAtIndex:1];
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
    CGRect rect = self.bottomBar.actionsComposeControl.frame;
    rect.size.width /= 2;
    rect = [self.view.superview convertRect:rect fromView:self.bottomBar];
    [self showThreadActionsFromRect:rect inView:self.view.superview];
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

- (void)tappedPageNav:(id)sender
{
    if (self.jumpToPageController) {
        [self dismissPopoverAnimated:YES];
        [self.jumpToPageController willMoveToParentViewController:nil];
        [self.jumpToPageController hideAnimated:YES completion:^{
            [self.pageNavBackingView removeFromSuperview];
        }];
        [self.jumpToPageController removeFromParentViewController];
        self.jumpToPageController = nil;
        return;
    }
    if (self.postsView.loadingMessage) return;
    if (self.thread.numberOfPagesValue < 1) return;
    self.jumpToPageController = [AwfulJumpToPageController new];
    self.jumpToPageController.delegate = self;
    [self.jumpToPageController reloadPages];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self.jumpToPageController reloadPages];
        self.popover = [[UIPopoverController alloc]
                        initWithContentViewController:self.jumpToPageController];
        self.popover.delegate = self;
        self.popover.popoverContentSize = self.jumpToPageController.view.bounds.size;
        [self.popover presentPopoverFromRect:self.bottomBar.jumpToPageButton.frame
                                      inView:self.bottomBar
                    permittedArrowDirections:UIPopoverArrowDirectionAny
                                    animated:YES];
    } else {
        UIView *halfBlack = [UIView new];
        halfBlack.frame = (CGRect){ .size = self.postsView.bounds.size };
        halfBlack.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
        halfBlack.autoresizingMask = (UIViewAutoresizingFlexibleWidth |
                                      UIViewAutoresizingFlexibleHeight);
        UITapGestureRecognizer *tap = [UITapGestureRecognizer new];
        [tap addTarget:self action:@selector(didTapPageNavBackground:)];
        [halfBlack addGestureRecognizer:tap];
        [self.view addSubview:halfBlack];
        [self.view bringSubviewToFront:self.bottomBar];
        self.pageNavBackingView = halfBlack;
        [self addChildViewController:self.jumpToPageController];
        [self.jumpToPageController showInView:self.pageNavBackingView animated:YES];
        [self.jumpToPageController didMoveToParentViewController:self];
    }
}

- (void)didTapPageNavBackground:(UITapGestureRecognizer *)tap
{
    if (tap.state != UIGestureRecognizerStateEnded) return;
    [self tappedPageNav:nil];
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
                 AwfulReplyViewController *reply = [AwfulReplyViewController new];
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
                 AwfulReplyViewController *reply = [AwfulReplyViewController new];
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
                 self.didJustMarkAsReadToHere = YES;
                 [self markPostsAsBeenSeenUpToPost:post];
             }
         }];
    }];
    [sheet addButtonWithTitle:[NSString stringWithFormat:@"%@ Profile", possessiveUsername] block:^{
        AwfulProfileViewController *profile = [AwfulProfileViewController new];
        profile.userID = post.author.userID;
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                  target:self action:@selector(doneWithProfile)];
            profile.navigationItem.leftBarButtonItem = done;
            UINavigationController *nav = [profile enclosingNavigationController];
            nav.modalPresentationStyle = UIModalPresentationFormSheet;
            [self presentViewController:nav animated:YES completion:nil];
        } else {
            profile.hidesBottomBarWhenPushed = YES;
            UIBarButtonItem *back = [[UIBarButtonItem alloc] initWithTitle:@"Back"
                                                                     style:UIBarButtonItemStyleBordered
                                                                    target:nil action:NULL];
            self.navigationItem.backBarButtonItem = back;
            [self.navigationController pushViewController:profile animated:YES];
        }
    }];
    [sheet addCancelButtonWithTitle:@"Cancel"];
    [sheet showFromRect:rect inView:view animated:YES];
}

- (void)dismissPopoverAnimated:(BOOL)animated
{
    if (self.popover) {
        [self.popover dismissPopoverAnimated:animated];
        self.popover = nil;
        if (self.jumpToPageController) self.jumpToPageController = nil;
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
    
    AwfulPageBottomBar *pageBar = [[AwfulPageBottomBar alloc] initWithFrame:pageBarFrame];
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
    self.bottomBar = pageBar;
    [self updatePageBar];
    
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
    
    [self.view bringSubviewToFront:self.bottomBar];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
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
    } else if ([keyPath isEqualToString:@"thread.seenPosts"]) {
        [self.postsView reloadData];
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
    if (self.jumpToPageController && !self.popover) {
        CGRect frame = self.jumpToPageController.view.frame;
        frame.size.width = self.view.frame.size.width;
        frame.origin.y = self.postsView.frame.size.height - frame.size.height;
        self.jumpToPageController.view.frame = frame;
    }
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [self.popover presentPopoverFromRect:self.bottomBar.jumpToPageButton.frame
                                  inView:self.bottomBar
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
    NSArray *keys = @[ @"postID", @"innerHTML" ];
    NSMutableDictionary *dict = [[post dictionaryWithValuesForKeys:keys] mutableCopy];
    if (post.postDate) {
        dict[@"postDate"] = [self.postDateFormatter stringFromDate:post.postDate];
    }
    if (post.author.username) dict[@"authorName"] = post.author.username;
    if (post.author.avatarURL) dict[@"authorAvatarURL"] = [post.author.avatarURL absoluteString];
    if ([post.author isEqual:post.thread.author]) dict[@"authorIsOriginalPoster"] = @YES;
    if (post.author.moderatorValue) dict[@"authorIsAModerator"] = @YES;
    if (post.author.administratorValue) dict[@"authorIsAnAdministrator"] = @YES;
    if (post.author.regdate) {
        dict[@"authorRegDate"] = [self.regDateFormatter stringFromDate:post.author.regdate];
    }
    dict[@"hasAttachment"] = @([post.attachmentID length] > 0);
    if (post.editDate) {
        NSString *editor = post.editor ? post.editor.username : @"Somebody";
        NSString *editDate = [self.editDateFormatter stringFromDate:post.editDate];
        dict[@"editMessage"] = [NSString stringWithFormat:@"%@ fucked around with this message on %@",
                                editor, editDate];
    }
    dict[@"beenSeen"] = @(post.beenSeen);
    return dict;
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

- (void)showMenuForLinkWithURLString:(NSString *)urlString
                  fromRectDictionary:(NSDictionary *)rectDict
{
    NSURL *url = [NSURL URLWithString:urlString];
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

- (NSDateFormatter *)editDateFormatter
{
    if (_editDateFormatter) return _editDateFormatter;
    _editDateFormatter = [NSDateFormatter new];
    // Jan 2, 2003 around 4:05
    _editDateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
    _editDateFormatter.dateFormat = @"MMM d, yyy 'around' HH:mm";
    return _editDateFormatter;
}

- (void)doneWithProfile
{
    [self dismissViewControllerAnimated:YES completion:nil];
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
    [self updatePullForNextPageLabel];
}

#pragma mark - AwfulSpecificPageControllerDelegate

- (NSInteger)numberOfPagesInJumpToPageController:(AwfulJumpToPageController *)controller
{
    return self.thread.numberOfPagesValue;
}

- (AwfulThreadPage)currentPageForJumpToPageController:(AwfulJumpToPageController *)controller
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

- (void)jumpToPageController:(AwfulJumpToPageController *)controller
               didSelectPage:(AwfulThreadPage)page
{
    if (self.popover) {
        [self dismissPopoverAnimated:YES];
    } else {
        [self.jumpToPageController hideAnimated:YES completion:^{
            [self.pageNavBackingView removeFromSuperview];
        }];
        self.jumpToPageController = nil;
    }
    [self loadPage:page];
}

#pragma mark - UIPopoverControllerDelegate

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popover
{
    if (popover == self.popover) {
        self.popover = nil;
        self.jumpToPageController = nil;
    }
}

#pragma mark - AwfulReplyViewControllerDelegate

- (void)replyViewController:(AwfulReplyViewController *)replyViewController
           didReplyToThread:(AwfulThread *)thread
{
    [self dismissViewControllerAnimated:YES completion:^{
        [self loadPage:AwfulThreadPageNextUnread];
    }];
}

- (void)replyViewController:(AwfulReplyViewController *)replyViewController
                didEditPost:(AwfulPost *)post
{
    [self dismissViewControllerAnimated:YES completion:^{
        [self loadPage:post.page];
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
