//
//  AwfulPostsViewController.m
//  Awful
//
//  Created by Sean Berry on 7/29/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPostsViewController.h"
#import "AwfulActionSheet.h"
#import "AwfulAppDelegate.h"
#import "AwfulDataStack.h"
#import "AwfulHTTPClient.h"
#import "AwfulModels.h"
#import "AwfulPageBar.h"
#import "AwfulPostsView.h"
#import "AwfulPullToRefreshControl.h"
#import "AwfulReplyViewController.h"
#import "AwfulSettings.h"
#import "AwfulSpecificPageViewController.h"
#import "AwfulThreadTitleLabel.h"
#import "MWPhoto.h"
#import "MWPhotoBrowser.h"
#import "NSFileManager+UserDirectories.h"
#import "NSManagedObject+Awful.h"
#import "SVProgressHUD.h"

@interface TopBarView : UIView

@property (readonly, weak, nonatomic) UIButton *goToForumButton;

@property (readonly, weak, nonatomic) UIButton *loadReadPostsButton;

@property (readonly, weak, nonatomic) UIButton *scrollToBottomButton;

@end


@interface AwfulPostsViewController () <AwfulPostsViewDelegate, NSFetchedResultsControllerDelegate>

@property (nonatomic) NSFetchedResultsController *fetchedResultsController;

@property (nonatomic) NSOperation *networkOperation;

@property (weak, nonatomic) AwfulPageBar *pageBar;

@property (nonatomic) AwfulSpecificPageViewController *specificPageController;

@property (weak, nonatomic) AwfulPostsView *postsView;

@property (weak, nonatomic) AwfulPullToRefreshControl *pullUpToRefreshControl;

@property (weak, nonatomic) TopBarView *topBar;

@property (copy, nonatomic) NSString *advertisementHTML;

@property (nonatomic) BOOL didJustMarkAsReadToHere;

@property (readonly, nonatomic) UILabel *titleLabel;

- (void)showThreadActionsFromRect:(CGRect)rect inView:(UIView *)view;

- (void)showActionsForPost:(AwfulPost *)post fromRect:(CGRect)rect inView:(UIView *)view;

@property (nonatomic) NSDateFormatter *regDateFormatter;

@property (nonatomic) NSDateFormatter *postDateFormatter;

@property (nonatomic) UIPopoverController *popover;

@property (nonatomic) BOOL markingPostsAsSeen;

@end


@implementation AwfulPostsViewController
{
    BOOL _observingScrollView;
}

- (id)init
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.hidesBottomBarWhenPushed = YES;
        self.navigationItem.titleView = NewAwfulThreadTitleLabel();
    }
    return self;
}

- (void)setThread:(AwfulThread *)thread
{
    if (_thread == thread) return;
    _thread = thread;
    self.titleLabel.text = thread.title;
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
        NSLog(@"error fetching posts in AwfulPostsView: %@", error);
    }
    if ([[self.fetchedResultsController fetchedObjects] count] == 0) {
        [self controllerDidChangeContent:self.fetchedResultsController];
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
    _currentPage = currentPage;
    [self updateFetchedResultsController];
    [self updatePageBar];
    [self updatePullForNextPageLabel];
}

- (UILabel *)titleLabel
{
    return (UILabel *)self.navigationItem.titleView;
}

- (void)refresh
{
    [self loadPage:self.currentPage];
}

- (void)loadPage:(NSInteger)page
{
    [self markPostsAsBeenSeen];
    [self.networkOperation cancel];
    [self hidePageNavigation];
    self.advertisementHTML = nil;
    if (page > 0) {
        self.currentPage = page;
        [self.postsView reloadData];
    } else {
        [self.postsView reloadAdvertisementHTML];
    }
    id op = [[AwfulHTTPClient client] listPostsInThreadWithID:self.thread.threadID
                                                       onPage:page
                                                      andThen:^(NSError *error, NSArray *posts, NSString *advertisementHTML)
    {
        if (error) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Could Not Load Page"
                                                            message:[error localizedDescription]
                                                           delegate:nil
                                                  cancelButtonTitle:@"Uh Huh"
                                                  otherButtonTitles:nil];
            [alert show];
            return;
        }
        self.advertisementHTML = advertisementHTML;
        AwfulPost *anyPost = [posts lastObject];
        if (page < 1) {
            self.currentPage = anyPost.threadPageValue;
        }
        [self.postsView reloadData];
        self.postsView.scrollView.contentOffset = CGPointZero;
        [self updatePageBar];
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
    self.markingPostsAsSeen = YES;
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
    self.markingPostsAsSeen = NO;
}

- (void)scrollToBottom
{
    UIScrollView *scrollView = self.postsView.scrollView;
    [scrollView scrollRectToVisible:CGRectMake(0, scrollView.contentSize.height - 1, 1, 1)
                           animated:YES];
}

- (void)loadNextPageOrRefresh
{
    NSArray *posts = [self.fetchedResultsController fetchedObjects];
    if (self.thread.numberOfPagesValue > self.currentPage || [posts count] >= 40) {
        [self loadPage:self.currentPage + 1];
    } else {
        [self loadPage:self.currentPage];
    }
}

- (void)updatePageBar
{
    [self.pageBar.backForwardControl setEnabled:self.currentPage != 1
                              forSegmentAtIndex:0];
    [self.pageBar.backForwardControl setEnabled:self.currentPage != self.thread.numberOfPagesValue
                              forSegmentAtIndex:1];
    [self.pageBar.jumpToPageButton setTitle:[NSString stringWithFormat:@"Page %d of %@",
                                             self.currentPage, self.thread.numberOfPages]
                                   forState:UIControlStateNormal];
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
                 NSLog(@"error %@bookmarking thread %@: %@", self.thread.isBookmarkedValue ? @"un" : @"", self.thread.threadID, error);
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
    [self dismissPopoverAnimated:YES];
    if (self.thread.numberOfPagesValue <= 0 || self.currentPage <= 0) return;
    
    UIView *sp_view = self.specificPageController.view;
    if (!sp_view)
    {
        self.specificPageController = [AwfulSpecificPageViewController new];
        self.specificPageController.page = self;
        sp_view = self.specificPageController.view;
        [self.specificPageController.pickerView selectRow:self.currentPage - 1
                                              inComponent:0
                                                 animated:NO];
    }
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        UIViewController *vc = self.specificPageController;
        
        self.popover = [[UIPopoverController alloc] initWithContentViewController:vc];
        
        [self.popover setPopoverContentSize:vc.view.bounds.size animated:NO];
        [self.popover presentPopoverFromRect:self.pageBar.jumpToPageButton.frame
                                      inView:self.pageBar
                    permittedArrowDirections:UIPopoverArrowDirectionAny
                                    animated:YES];
    } else {
        if (self.specificPageController != nil && !self.specificPageController.hiding) {
            self.specificPageController.hiding = YES;
            [UIView animateWithDuration:0.3
                                  delay:0.0
                                options:UIViewAnimationOptionCurveEaseInOut
                             animations:^{
                                 sp_view.frame = CGRectOffset(sp_view.frame, 0, sp_view.frame.size.height + self.pageBar.bounds.size.height);
                             } completion:^(BOOL finished)
             {
                 [sp_view removeFromSuperview];
                 self.specificPageController = nil;
             }];
            
        } else if(self.specificPageController == nil) {
            self.specificPageController = [AwfulSpecificPageViewController new];
            self.specificPageController.page = self;
            sp_view = self.specificPageController.view;
            sp_view.frame = CGRectMake(0, self.view.frame.size.height, self.view.frame.size.width, sp_view.frame.size.height);
            
            [self.view addSubview:sp_view];
            [self.view bringSubviewToFront:self.pageBar];
            [UIView animateWithDuration:0.3 animations:^{
                sp_view.frame = CGRectOffset(sp_view.frame, 0, -sp_view.frame.size.height - self.pageBar.bounds.size.height);
            }];
        }
    }
}

- (void)hidePageNavigation
{
    [self dismissPopoverAnimated:YES];
    if (self.specificPageController) [self tappedPageNav:nil];
}

- (void)tappedCompose
{
    [self dismissPopoverAnimated:YES];
    AwfulReplyViewController *postBox = [AwfulReplyViewController new];
    postBox.thread = self.thread;
    postBox.page = self;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:postBox];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)showActionsForPost:(AwfulPost *)post fromRect:(CGRect)rect inView:(UIView *)view
{
    [self dismissPopoverAnimated:YES];
    NSString *title = [NSString stringWithFormat:@"%@'s Post", post.authorName];
    if ([post.authorName isEqualToString:[AwfulSettings settings].currentUser.username]) {
        title = @"Your Post";
    }
    AwfulActionSheet *sheet = [[AwfulActionSheet alloc] initWithTitle:title];
    if (post.editableValue) {
        [sheet addButtonWithTitle:@"Edit" block:^{
            [[AwfulHTTPClient client] getTextOfPostWithID:post.postID
                                                  andThen:^(NSError *error, NSString *text)
             {
                 if (error) {
                     UIAlertView *alert = [UIAlertView new];
                     alert.title = @"Could Not Edit Post";
                     alert.message = [error localizedDescription];
                     [alert addButtonWithTitle:@"Alright"];
                     [alert show];
                     return;
                 }
                 AwfulReplyViewController *reply = [AwfulReplyViewController new];
                 reply.post = post;
                 reply.startingText = text;
                 reply.page = self;
                 UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:reply];
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
                     UIAlertView *alert = [UIAlertView new];
                     alert.title = @"Could Not Quote Post";
                     alert.message = [error localizedDescription];
                     [alert addButtonWithTitle:@"Alright"];
                     [alert show];
                     return;
                 }
                 AwfulReplyViewController *reply = [AwfulReplyViewController new];
                 reply.thread = self.thread;
                 reply.startingText = [quotedText stringByAppendingString:@"\n\n"];
                 reply.page = self;
                 UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:reply];
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
                 UIAlertView *alert = [UIAlertView new];
                 alert.title = @"Could Not Mark Read";
                 alert.message = [error localizedDescription];
                 [alert addButtonWithTitle:@"Alright"];
                 [alert show];
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
    [self.popover dismissPopoverAnimated:animated];
    self.popover = nil;
}

#pragma mark - UIViewController

- (void)loadView
{
    self.view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.view.backgroundColor = [UIColor underPageBackgroundColor];
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
    
    AwfulPostsView *postsView = [[AwfulPostsView alloc] initWithFrame:postsFrame];
    postsView.delegate = self;
    postsView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    postsView.backgroundColor = [UIColor underPageBackgroundColor];
    postsView.dark = [AwfulSettings settings].darkTheme;
    self.postsView = postsView;
    [self.view addSubview:postsView];
    
    TopBarView *topBar = [TopBarView new];
    topBar.frame = CGRectMake(0, 0, self.view.frame.size.width, -44);
    topBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    topBar.goToForumButton.enabled = NO;
    [topBar.loadReadPostsButton addTarget:postsView
                                   action:@selector(showHiddenSeenPosts)
                         forControlEvents:UIControlEventTouchUpInside];
    topBar.loadReadPostsButton.enabled = NO;
    [topBar.scrollToBottomButton addTarget:self
                                    action:@selector(scrollToBottom)
                          forControlEvents:UIControlEventTouchUpInside];
    [postsView.scrollView addSubview:topBar];
    self.topBar = topBar;
    postsView.scrollView.contentInset = UIEdgeInsetsMake(44, 0, 0, 0);
    [self keepTopBarHiddenOnFirstView];
    
    AwfulPullToRefreshControl *refresh;
    refresh = [[AwfulPullToRefreshControl alloc] initWithDirection:AwfulScrollViewPullUp];
    [refresh addTarget:self
                action:@selector(loadNextPageOrRefresh)
      forControlEvents:UIControlEventValueChanged];
    refresh.backgroundColor = self.topBar.backgroundColor;
    [self.postsView.scrollView addSubview:refresh];
    self.pullUpToRefreshControl = refresh;
}

// We want to hide the top bar until the user reveals it. Unfortunately, AwfulPostsView's
// scrollView changes its contentSize at some arbitrary point (when it loads the posts we send it),
// which changes the contentOffset to reveal the top bar.
//
// Here, we simply override that first attempt to set the contentOffset too high.
- (void)keepTopBarHiddenOnFirstView
{
    _observingScrollView = YES;
    [self.postsView.scrollView addObserver:self
                                forKeyPath:@"contentOffset"
                                   options:NSKeyValueObservingOptionNew
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
    
    CGPoint offset = [change[NSKeyValueChangeNewKey] CGPointValue];
    if (offset.y < 0) {
        [object setContentOffset:CGPointZero];
        [object removeObserver:self forKeyPath:keyPath context:context];
        _observingScrollView = NO;
    }
}

static void * KVOContext = @"AwfulPostsView KVO";

- (void)dealloc
{
    if (_observingScrollView) {
        [self.postsView.scrollView removeObserver:self
                                       forKeyPath:@"contentOffset"
                                          context:&KVOContext];
    }
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

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                         duration:(NSTimeInterval)duration
{
    if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) {
        UIView *sp_view = self.specificPageController.view;
        sp_view.frame = CGRectMake(0, self.view.frame.size.height - sp_view.frame.size.height - self.pageBar.frame.size.height,
                                   self.view.frame.size.width, sp_view.frame.size.height);
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
    return [[self.fetchedResultsController fetchedObjects] count];
}

- (NSDictionary *)postsView:(AwfulPostsView *)postsView postAtIndex:(NSInteger)index
{
    NSArray *posts = [self.fetchedResultsController fetchedObjects];
    AwfulPost *post = posts[index];
    NSArray *keys = @[
        @"postID", @"authorName", @"authorAvatarURL", @"beenSeen", @"innerHTML",
        @"authorIsOriginalPoster", @"authorIsAModerator", @"authorIsAnAdministrator"
    ];
    NSMutableDictionary *dict = [[post dictionaryWithValuesForKeys:keys] mutableCopy];
    dict[@"postDate"] = [self.postDateFormatter stringFromDate:post.postDate];
    dict[@"authorRegDate"] = [self.regDateFormatter stringFromDate:post.authorRegDate];
    return dict;
}

- (NSString *)advertisementHTMLForPostsView:(AwfulPostsView *)postsView
{
    return self.advertisementHTML;
}

- (void)postsView:(AwfulPostsView *)postsView numberOfHiddenSeenPosts:(NSInteger)hiddenPosts
{
    self.topBar.loadReadPostsButton.enabled = hiddenPosts > 0;
}

- (void)postsView:(AwfulPostsView *)postsView didTapLinkToURL:(NSURL *)url
{
    // TODO intercept links to forums, threads, posts and show in-app.
    // N.B. Some links have no host and go to showthread.php
    [[UIApplication sharedApplication] openURL:url];
}

- (void)showActionsForPostAtIndex:(NSNumber *)index fromRectDictionary:(NSDictionary *)rectDict
{
    NSArray *posts = [self.fetchedResultsController fetchedObjects];
    AwfulPost *post = posts[[index integerValue]];
    CGRect rect = CGRectMake([rectDict[@"left"] floatValue], [rectDict[@"top"] floatValue],
                             [rectDict[@"width"] floatValue], [rectDict[@"height"] floatValue]);
    [self showActionsForPost:post fromRect:rect inView:self.postsView];
}

- (void)previewImageAtURLString:(NSString *)urlString
{
    NSArray *photos = @[ [MWPhoto photoWithURL:[NSURL URLWithString:urlString]] ];
    MWPhotoBrowser *browser = [[MWPhotoBrowser alloc] initWithPhotos:photos];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:browser];
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

- (void)controller:(NSFetchedResultsController *)controller
   didChangeObject:(AwfulPost *)post
       atIndexPath:(NSIndexPath *)indexPath
     forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    if (self.markingPostsAsSeen) return;
    if (type == NSFetchedResultsChangeInsert) {
        [self.postsView insertPostAtIndex:indexPath.row];
    } else if (type == NSFetchedResultsChangeDelete) {
        [self.postsView deletePostAtIndex:indexPath.row];
    } else if (type == NSFetchedResultsChangeUpdate) {
        [self.postsView reloadPostAtIndex:indexPath.row];
    } else if (type == NSFetchedResultsChangeMove) {
        [self.postsView deletePostAtIndex:indexPath.row];
        [self.postsView insertPostAtIndex:newIndexPath.row];
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [self.pullUpToRefreshControl setRefreshing:NO animated:YES];
    [self updatePullForNextPageLabel];
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
    
    self.backgroundColor = [UIColor colorWithWhite:0.902 alpha:1];
    
    UIButton *goToForumButton = [self makeButton];
    [goToForumButton setTitle:@"Go To\nForum" forState:UIControlStateNormal];
    [goToForumButton setImage:[UIImage imageNamed:@"go-to-forum.png"]
                     forState:UIControlStateNormal];
    _goToForumButton = goToForumButton;
    
    UIButton *loadReadPostsButton = [self makeButton];
    [loadReadPostsButton setTitle:@"Load Read\nPosts" forState:UIControlStateNormal];
    [loadReadPostsButton setImage:[UIImage imageNamed:@"load-read-posts.png"]
                         forState:UIControlStateNormal];
    _loadReadPostsButton = loadReadPostsButton;
    
    UIButton *scrollToBottomButton = [self makeButton];
    [scrollToBottomButton setTitle:@"Scroll To\nBottom" forState:UIControlStateNormal];
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
    [button setTitleColor:[UIColor colorWithHue:0.590
                                     saturation:0.771
                                     brightness:0.376
                                          alpha:1.000]
                 forState:UIControlStateNormal];
    [button setTitleShadowColor:[UIColor whiteColor]
                       forState:UIControlStateNormal];
    [button setTitleColor:[UIColor lightGrayColor] forState:UIControlStateDisabled];
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
