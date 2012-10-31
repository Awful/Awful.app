//
//  AwfulPage.m
//  Awful
//
//  Created by Sean Berry on 7/29/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPage.h"
#import "AwfulActionSheet.h"
#import "AwfulAppDelegate.h"
#import "AwfulDataStack.h"
#import "AwfulHTTPClient.h"
#import "AwfulModels.h"
#import "AwfulPageBar.h"
#import "AwfulPostsView.h"
#import "AwfulReplyViewController.h"
#import "AwfulSettings.h"
#import "AwfulSpecificPageViewController.h"
#import "AwfulThreadTitleLabel.h"
#import "MWPhoto.h"
#import "MWPhotoBrowser.h"
#import "NSFileManager+UserDirectories.h"
#import "NSManagedObject+Awful.h"
#import "SVProgressHUD.h"

@interface AwfulPage () <AwfulPostsViewDelegate>

@property (nonatomic) NSOperation *networkOperation;

@property (weak, nonatomic) AwfulPageBar *pageBar;

@property (nonatomic) AwfulSpecificPageViewController *specificPageController;

@property (weak, nonatomic) AwfulPostsView *postsView;

@property (copy, nonatomic) NSArray *posts;

@property (nonatomic) BOOL didJustMarkAsReadToHere;

@property (readonly, nonatomic) UILabel *titleLabel;

- (void)showThreadActionsFromRect:(CGRect)rect inView:(UIView *)view;

- (void)showActionsForPost:(AwfulPost *)post fromRect:(CGRect)rect inView:(UIView *)view;

@end


@implementation AwfulPage

+ (id)newDeviceSpecificPage
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return [AwfulPageIpad new];
    }
    return [self new];
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

- (void)setPosts:(NSArray *)posts
{
    if (_posts == posts) return;
    _posts = [posts copy];
    AwfulPost *anyPost = [posts lastObject];
    self.thread = anyPost.thread;
    self.currentPage = anyPost.threadPageValue;
    [self.postsView reloadData];
    [[NSNotificationCenter defaultCenter] postNotificationName:AwfulPageDidLoadNotification
                                                        object:self.thread
                                                      userInfo:@{ @"page" : self }];
}

- (void)setCurrentPage:(NSInteger)currentPage
{
    _currentPage = currentPage;
    [self updatePageBar];
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
        // TODO pass advertisement along to posts view
        self.posts = posts;
        AwfulPost *anyPost = [self.posts lastObject];
        self.currentPage = anyPost.threadPageValue;
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
    AwfulPost *lastPost = [self.posts lastObject];
    if (!lastPost || lastPost.beenSeenValue) return;
    [self markPostsAsBeenSeenUpToPost:lastPost];
}

- (void)markPostsAsBeenSeenUpToPost:(AwfulPost *)post
{
    NSUInteger lastSeen = [self.posts indexOfObject:post];
    if (lastSeen == NSNotFound) return;
    for (NSUInteger i = 0; i < [self.posts count]; i++) {
        [self.posts[i] setBeenSeenValue:i <= lastSeen];
    }
    NSInteger readPosts = post.threadIndexValue - 1;
    if (self.thread.totalRepliesValue < readPosts) {
        // This can happen if new replies appear in between times we parse the total number of
        // replies in the thread.
        self.thread.totalRepliesValue = readPosts;
    }
    self.thread.totalUnreadPostsValue = self.thread.totalRepliesValue - readPosts;
    [[AwfulDataStack sharedDataStack] save];
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
}

- (AwfulPostsView *)postsView
{
    if (!_postsView) [self view];
    return _postsView;
}

- (void)viewDidDisappear:(BOOL)animated
{
    // Blank the web view if we're leaving for good. Otherwise we get weirdness like videos
    // continuing to play their sound after the user switches to a different thread.
    if (!self.navigationController) {
        [self.postsView clearAllPosts];
    }
    [self markPostsAsBeenSeen];
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

#pragma mark - BarButtonItem Actions

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

- (IBAction)tappedPagesSegment:(id)sender
{
    UISegmentedControl *backForward = sender;
    if (backForward.selectedSegmentIndex == 0) {
        [self prevPage];
    } else if (backForward.selectedSegmentIndex == 1) {
        [self nextPage];
    }
    backForward.selectedSegmentIndex = UISegmentedControlNoSegment;
}

- (IBAction)tappedActionsSegment:(id)sender
{
    UISegmentedControl *actions = sender;
    if (actions.selectedSegmentIndex == 0) {
        [self tappedActions];
    } else if (actions.selectedSegmentIndex == 1) {
        [self tappedCompose];
    }
    actions.selectedSegmentIndex = UISegmentedControlNoSegment;
}

- (IBAction)tappedNextPage:(id)sender
{
    [self nextPage];
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

- (IBAction)tappedActions
{
    CGRect rect = [self.view convertRect:self.pageBar.frame toView:self.view.superview];
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
    if (self.thread.numberOfPagesValue <= 0 || self.currentPage <= 0) {
        return;
    }
    
    UIView *sp_view = self.specificPageController.view;
    
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
        
        [self.specificPageController.pickerView selectRow:self.currentPage - 1
                                              inComponent:0
                                                 animated:NO];
    }
}
       
- (void)hidePageNavigation
{
    if (self.specificPageController != nil) {
        [self tappedPageNav:nil];
    }
}

- (IBAction)tappedCompose
{
    AwfulReplyViewController *postBox = [AwfulReplyViewController new];
    postBox.thread = self.thread;
    postBox.page = self;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:postBox];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)showActionsForPost:(AwfulPost *)post fromRect:(CGRect)rect inView:(UIView *)view
{
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
                 NSUInteger postIndex = [self.posts indexOfObject:post];
                 if (postIndex != NSNotFound) [self markPostsAsBeenSeenUpToPost:post];
             }
         }];
    }];
    [sheet addCancelButtonWithTitle:@"Cancel"];
    [sheet showFromRect:rect inView:view animated:YES];
}

#pragma mark - Gesture recognizer delegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture
    shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other
{
    return YES;
}

#pragma mark - Web view delegate

- (BOOL)webView:(UIWebView *)webView
    shouldStartLoadWithRequest:(NSURLRequest *)request
    navigationType:(UIWebViewNavigationType)navigationType
{
    if (navigationType != UIWebViewNavigationTypeLinkClicked) {
        return YES;
    }
    NSURL *url = request.URL;
    if ([[url host] isEqualToString:@"forums.somethingawful.com"] &&
        [[url lastPathComponent] isEqualToString:@"showthread.php"]) {
        NSDictionary *query = [[request URL] queryDictionary];
        NSString *threadID = query[@"threadid"];
        NSString *pageNumber = query[@"pagenumber"];
        
        // TODO (nolan) idgi, why a throwaway context?
        if (threadID) {
            NSManagedObjectModel *model = [NSManagedObjectModel mergedModelFromBundles:nil];
            NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
            NSManagedObjectContext *moc = [NSManagedObjectContext new];
            [moc setPersistentStoreCoordinator:coordinator];
            [moc setUndoManager:nil];
            AwfulThread *intra = [AwfulThread insertInManagedObjectContext:moc];
            intra.threadID = threadID;
            AwfulPage *page = [AwfulPage newDeviceSpecificPage];
            page.thread = intra;
            [self.navigationController pushViewController:page animated:YES];
            if (pageNumber != nil) {
                [page loadPage:[pageNumber integerValue]];
            } else {
                [page loadPage:1];
            }
            return NO;
        }
    } else if (![url host] && [[url lastPathComponent] isEqualToString:@"showthread.php"]) {
        // TODO when does this happen?
        url = [NSURL URLWithString:[NSString stringWithFormat:@"http://forums.somethingawful.com/%@",
                                    request.URL]];
    }
    [[UIApplication sharedApplication] openURL:url];
    return NO;
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
    return [self.posts count];
}

- (NSDictionary *)postsView:(AwfulPostsView *)postsView postAtIndex:(NSInteger)index
{
    AwfulPost *post = self.posts[index];
    NSArray *keys = @[ @"postID", @"authorName", @"authorAvatarURL", @"beenSeen", @"innerHTML" ];
    NSMutableDictionary *dict = [[post dictionaryWithValuesForKeys:keys] mutableCopy];
    dict[@"postDate"] = [NSDateFormatter localizedStringFromDate:post.postDate
                                                       dateStyle:NSDateFormatterMediumStyle
                                                       timeStyle:NSDateFormatterShortStyle];
    dict[@"authorRegDate"] = [NSDateFormatter localizedStringFromDate:post.authorRegDate
                                                            dateStyle:NSDateFormatterMediumStyle
                                                            timeStyle:NSDateFormatterNoStyle];
    return dict;
}

- (void)showActionsForPostAtIndex:(NSNumber *)index fromRectDictionary:(NSDictionary *)rectDict
{
    AwfulPost *post = self.posts[[index integerValue]];
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

@end


NSString * const AwfulPageWillLoadNotification = @"com.awfulapp.Awful.PageWillLoadNotification";
NSString * const AwfulPageDidLoadNotification = @"com.awfulapp.Awful.PageDidLoadNotification";


@interface AwfulPageIpad ()

@property (nonatomic, strong) UIPopoverController *popController;

@end


@implementation AwfulPageIpad

- (IBAction)tappedPageNav:(id)sender
{
    if (self.popController)
    {
        [self.popController dismissPopoverAnimated:YES];
        self.popController = nil;
    }
    
    if (self.thread.numberOfPagesValue <= 0 || self.currentPage <= 0)
    {
        return;
    }
    
    UIView *sp_view = self.specificPageController.view;
        
    if (!self.specificPageController)
    {
        self.specificPageController = [AwfulSpecificPageViewController new];
        self.specificPageController.page = self;
        [self.specificPageController loadView];
        sp_view = self.specificPageController.view;
        
        [self.specificPageController.pickerView selectRow:self.currentPage - 1
                                              inComponent:0
                                                 animated:NO];
    }

    UIViewController *vc = self.specificPageController;

    self.popController = [[UIPopoverController alloc] initWithContentViewController:vc];
    
    [self.popController setPopoverContentSize:vc.view.bounds.size animated:NO];
    [self.popController presentPopoverFromRect:self.pageBar.jumpToPageButton.frame
                                        inView:self.pageBar
                      permittedArrowDirections:UIPopoverArrowDirectionAny
                                      animated:YES];
}

- (void)tappedActions
{
    CGRect rect = self.pageBar.actionsComposeControl.frame;
    rect.size.width /= 2;
    [self showThreadActionsFromRect:rect inView:self.pageBar.actionsComposeControl.superview];
}

- (void)showActionsForPost:(AwfulPost *)post fromRect:(CGRect)rect inView:(UIView *)view
{
    if (self.popController) {
        [self.popController dismissPopoverAnimated:YES];
        self.popController = nil;
    }
    [super showActionsForPost:post fromRect:rect inView:view];
}

- (IBAction)tappedCompose
{
    if (self.popController)
    {
        [self.popController dismissPopoverAnimated:YES];
        self.popController = nil;
    }
    
    [super tappedCompose];
}

- (void)hidePageNavigation
{
    if (self.popController) {
        [self.popController dismissPopoverAnimated:YES];
        self.popController = nil;
    }
}

@end
