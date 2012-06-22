//
//  AwfulPage.m
//  Awful
//
//  Created by Sean Berry on 7/29/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulThreadListController.h"
#import <QuartzCore/QuartzCore.h>
#import "AwfulAppDelegate.h"
#import "AwfulLoginController.h"
#import "AwfulPageDataController.h"
#import "AwfulPost.h"
#import "AwfulPostActions.h"
#import "AwfulSettings.h"
#import "AwfulSpecificPageViewController.h"
#import "AwfulThreadActions.h"
#import "AwfulUser.h"
#import "AwfulUser+AwfulMethods.h"
#import "AwfulVoteActions.h"
#import "ButtonSegmentedControl.h"
#import "MBProgressHUD.h"
#import "MWPhoto.h"
#import "MWPhotoBrowser.h"
#import "OtherWebController.h"
//#import "AwfulUtil.h"
#import "AwfulLoadingFooterView.h"
#import "AwfulLoadingHeaderView.h"
#import "AwfulPage+Transitions.h"
#import "AwfulWebViewDelegate.h"

@interface AwfulPage () <AwfulWebViewDelegate, UIGestureRecognizerDelegate>

//@property (nonatomic, strong) IBOutlet UIWebView *webView;
@property (strong) AwfulWebViewDelegateWrapper *webViewDelegateWrapper;

@end

@implementation AwfulPage

@synthesize destinationType = _destinationType;
@synthesize thread = _thread;
@synthesize threadID = _threadID;
@synthesize url = _url;
@synthesize webView = _webView;
@synthesize nextPageWebView = _nextPageWebView;
@synthesize toolbar = _toolbar;
@synthesize isBookmarked = _isBookmarked;
@synthesize currentPage = _currentPage;
@synthesize numberOfPages = _numberOfPages;
@synthesize shouldScrollToBottom = _shouldScrollToBottom;
@synthesize postIDScrollDestination = _postIDScrollDestination;
@synthesize specificPageController = _specificPageController;
@synthesize dataController = _dataController;
@synthesize networkOperation = _networkOperation;
@synthesize actions = _actions;
@synthesize pagesBarButtonItem = _pagesBarButtonItem;
@synthesize nextPageBarButtonItem = _nextPageBarButtonItem;
@synthesize draggingUp = _draggingUp;
@synthesize pagesSegmentedControl = _pagesSegmentedControl;
@synthesize actionsSegmentedControl = _actionsSegmentedControl;
@synthesize isFullScreen = _isFullScreen;
@synthesize loadingFooterView = _loadingFooterView;
@synthesize pullForActionController = _pullForActionController;
@synthesize autoRefreshTimer = _autoRefreshTimer;
//@synthesize skipBlankingWebViewOnce = _skipBlankingWebViewOnce;
/*
- (BOOL)skipBlankingWebViewOnce
{
    if (!_skipBlankingWebViewOnce) {
        return NO;
    }
    _skipBlankingWebViewOnce = NO;
    return YES;
}
*/
#pragma mark - Initialization

-(void)awakeFromNib
{    
    self.actionsSegmentedControl.action = @selector(tappedActionsSegment:);
    self.pagesSegmentedControl.action = @selector(tappedPagesSegment:);
    //self.webView.scrollView.delegate = self;
    self.view.backgroundColor = [UIColor underPageBackgroundColor];
    self.webView.backgroundColor = [UIColor scrollViewTexturedBackgroundColor];
    //if (!self.pullToNavigateView) {
    //    self.pullToNavigateView = [AwfulLoadingFooterView new];
    //}
    //self.pullToNavigateView.delegate = self;
    //self.pullToNavigateView.scrollView = self.webView.scrollView;
    
    //CGRect frame = self.webView.frame;
    //frame.origin.y = frame.size.height;
    
    //self.nextPageWebView = [JSBridgeWebView new];
    //self.nextPageWebView.frame = frame;
    

    

    self.pullForActionController = [[AwfulPullForActionController alloc] initWithScrollView:self.webView.scrollView];
    self.pullForActionController.headerView = [[AwfulLoadingHeaderView alloc] initWithFrame:CGRectMake(0, 0, 100, 60)]; 
    self.pullForActionController.delegate = self;
    
    self.loadingFooterView = [AwfulLoadingFooterView new];
    [self.loadingFooterView.autoF5 addTarget:self 
                                      action:@selector(didSwitchAutoF5:) 
                            forControlEvents:UIControlEventValueChanged];
    self.pullForActionController.footerView = self.loadingFooterView;
}

- (AwfulThread *) thread
{
    if ([_thread isFault])
    {
        NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:[AwfulThread entityName]];
        [request setPredicate:[NSPredicate predicateWithFormat:@"threadID like %@", self.threadID]];
        NSArray *results = [ApplicationDelegate.managedObjectContext executeFetchRequest:request error:nil];
        
        _thread = [results objectAtIndex:0];
    }
    return _thread;
}

-(void)setThread:(AwfulThread *)newThread
{

    if(_thread != newThread) {
        _thread = newThread;
        self.threadID = _thread.threadID;
        if(_thread.title != nil) {
            UILabel *lab = (UILabel *)self.navigationItem.titleView;
            lab.text = self.thread.title;
                //NSLog(@"title width %f", self.navigationItem.titleView.frame.size.width);
        }
        
        if([_thread.totalUnreadPosts intValue] == -1) {
            self.destinationType = AwfulPageDestinationTypeFirst;
            
        } else if([_thread.totalUnreadPosts intValue] == 0) {
            self.destinationType = AwfulPageDestinationTypeLast;
                // if the last page is full, it won't work if you go for &goto=newpost, that's why I'm setting this to last page
        } else {
            self.destinationType = AwfulPageDestinationTypeNewpost;
        }
    }
}


-(void)setDestinationType:(AwfulPageDestinationType)destinationType
{
    _destinationType = destinationType;
    self.shouldScrollToBottom = (_destinationType == AwfulPageDestinationTypeLast);
}

-(void)setDataController:(AwfulPageDataController *)dataController
{
    if(_dataController != dataController) {
        _dataController = dataController;
        self.currentPage = dataController.currentPage;
        self.numberOfPages = dataController.numberOfPages;
        [self setThreadTitle:dataController.threadTitle];
        
        self.postIDScrollDestination = [dataController calculatePostIDScrollDestination];
        self.shouldScrollToBottom = [dataController shouldScrollToBottom];
        if(self.destinationType != AwfulPageDestinationTypeNewpost) {
            self.shouldScrollToBottom = NO;
        }
        
        int numNewPosts = [_dataController numNewPostsLoaded];
        if(numNewPosts > 0 && (self.destinationType == AwfulPageDestinationTypeNewpost || self.currentPage == self.numberOfPages)) {
            int unreadPosts = [self.thread.totalUnreadPosts intValue];
            if(unreadPosts != -1) {
                unreadPosts -= numNewPosts;
                self.thread.totalUnreadPosts = [NSNumber numberWithInt:MAX(unreadPosts, 0)];
                [ApplicationDelegate saveContext];
            }
        } else if(self.destinationType == AwfulPageDestinationTypeLast) {
            self.thread.totalUnreadPosts = [NSNumber numberWithInt:0];
            [ApplicationDelegate saveContext];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:AwfulThreadDidUpdateNotification object:self.thread];
        
        NSString *html = [dataController constructedPageHTML];
        
        //if nextPageWebView is null, then it's the initial load
        if (self.nextPageWebView) {
            [self.nextPageWebView loadHTMLString:html baseURL:[NSURL URLWithString:@"http://forums.somethingawful.com"]];
            self.nextPageWebView.tag = self.currentPage;
        }
        else {
            [self.webView loadHTMLString:html baseURL:[NSURL URLWithString:@"http://forums.somethingawful.com"]];
            self.webView.tag = self.currentPage;
            
            self.nextPageWebView = [UIWebView new];
            self.nextPageWebView.delegate = self;
            self.nextPageWebView.frame = self.webView.frame;
            self.nextPageWebView.foY = self.nextPageWebView.fsH;
            [self.view addSubview:self.nextPageWebView];
        }
    }
    
}

- (void)setCurrentPage:(NSInteger)currentPage
{
    _currentPage = currentPage;
    [self updatePagesLabel];
}

- (void)setNumberOfPages:(NSInteger)numberOfPages
{
    _numberOfPages = numberOfPages;
    [self updatePagesLabel];
}

-(void)setThreadTitle : (NSString *)title
{
    AwfulThread *mythread = self.thread;
    mythread.title = title;
    UILabel *lab = (UILabel *)self.navigationItem.titleView;
    lab.text = title;
    lab.adjustsFontSizeToFitWidth = YES;
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if([[segue identifier] isEqualToString:@"ReplyBox"]) {
        AwfulPostBoxController *postBox = (AwfulPostBoxController *)segue.destinationViewController;
        postBox.thread = self.thread;
        postBox.page = self;
    } else if([[segue identifier] isEqualToString:@"EditPost"]) {
        if([sender isMemberOfClass:[AwfulPostActions class]]) {
            AwfulPostActions *actions = (AwfulPostActions *)sender;
            AwfulPostBoxController *editBox = (AwfulPostBoxController *)segue.destinationViewController;
            editBox.post = actions.post;
            editBox.startingText = actions.postContents;
            editBox.page = self;
        }
    } else if([[segue identifier] isEqualToString:@"QuoteBox"]) {
        if([sender isMemberOfClass:[AwfulPostActions class]]) {
            AwfulPostActions *actions = (AwfulPostActions *)sender;
            AwfulPostBoxController *quoteBox = (AwfulPostBoxController *)segue.destinationViewController;
            quoteBox.thread = self.thread;
            quoteBox.startingText = actions.postContents;
            quoteBox.page = self;
        }
    }
}

-(IBAction)hardRefresh
{    
    self.nextPageWebView = nil;
    int posts_per_page = [AwfulUser currentUser].postsPerPageValue;
    if([self.dataController.posts count] == posts_per_page) {
        self.destinationType = AwfulPageDestinationTypeSpecific;
        [self refresh];
    } else {
        self.destinationType = AwfulPageDestinationTypeNewpost;
        [self refresh];
    }
}

-(void)refresh
{        
    //self.nextPageWebView = nil;
    [self loadPageNum:self.currentPage];
}

-(void)loadPageNum : (NSUInteger)pageNum
{
    // I guess the error callback doesn't necessarily get called when a network operation is 
    // cancelled, so clear the HUD when we cancel the network operation.
    [MBProgressHUD hideHUDForView:self.view animated:NO];
    [self.networkOperation cancel];
    
    [self swapToStopButton];
    [self hidePageNavigation];
    if(pageNum != 0) {
        //MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:NO];
        //hud.labelText = [NSString stringWithFormat:@"Loading Page %d", pageNum];
        
        //self.pullToNavigateView.state = AwfulPullForActionStateLoading;
        //self.pullToNavigateView.statusLabel = [NSString stringWithFormat:@"Loading Page %d", pageNum];
    }
    
    AwfulThread *myThread = self.thread;
    AwfulPageDestinationType destType = self.destinationType;
    self.networkOperation = [[AwfulHTTPClient sharedClient] pageDataForThread:myThread destinationType:destType pageNum:pageNum onCompletion:^(AwfulPageDataController *dataController) {
        self.dataController = dataController;
        if(self.destinationType == AwfulPageDestinationTypeSpecific) {
            self.currentPage = pageNum;
        }
        [self updatePagesLabel];
        [self updateBookmarked];
        [self swapToRefreshButton];
        //[MBProgressHUD hideHUDForView:self.view animated:NO];
        
        self.loadingFooterView.onLastPage = (self.currentPage == self.numberOfPages);
        
        self.webView.scrollView.contentInset = self.loadingFooterView.onLastPage?
            UIEdgeInsetsMake(0, 0, self.pullForActionController.footerView.fsH, 0) :
            UIEdgeInsetsZero;

        
    } onError:^(NSError *error) {
        [self swapToRefreshButton];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Failed" message:[error localizedDescription] delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
        [alert show];
        [MBProgressHUD hideHUDForView:self.view animated:NO];
    }];
}

-(void)loadLastPage
{
    [self.networkOperation cancel];
    [self swapToStopButton];
    self.networkOperation = [[AwfulHTTPClient sharedClient] pageDataForThread:self.thread destinationType:AwfulPageDestinationTypeLast pageNum:0 onCompletion:^(AwfulPageDataController *dataController) {
        self.dataController = dataController;
        [self updatePagesLabel];
        [self updateBookmarked];
        [self swapToRefreshButton];
        //self.pullToNavigateView.onLastPage = YES;
    } onError:^(NSError *error) {
        [self swapToRefreshButton];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Failed" message:[error localizedDescription] delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
        [alert show];
    }];
}

-(void)stop
{
    [self.networkOperation cancel];
    [self swapToRefreshButton];
    [MBProgressHUD hideHUDForView:self.view animated:NO];
    [self.webView stopLoading];
}

-(void)loadOlderPosts
{
    NSString *html = [self.dataController constructedPageHTMLWithAllPosts];
    [self.webView loadHTMLString:html baseURL:[NSURL URLWithString:@"http://forums.somethingawful.com"]];
}

-(void)heldPost:(UILongPressGestureRecognizer *)gestureRecognizer
{    
    CGPoint p = [gestureRecognizer locationInView:self.webView];
    
    NSString *js_tag_name = [NSString stringWithFormat:@"document.elementFromPoint(%f, %f).tagName", p.x, p.y];
    NSString *tag_name = [self.webView stringByEvaluatingJavaScriptFromString:js_tag_name];
    if([tag_name isEqualToString:@"IMG"]) {
        NSString *js_src = [NSString stringWithFormat:@"document.elementFromPoint(%f, %f).src", p.x, p.y];
        NSString *src = [self.webView stringByEvaluatingJavaScriptFromString:js_src];
        NSString *js_class = [NSString stringWithFormat:@"document.elementFromPoint(%f, %f).className", p.x, p.y];
        NSString *class = [self.webView stringByEvaluatingJavaScriptFromString:js_class];
        
        BOOL proceed = YES;
        
        if([class isEqualToString:@"postaction"]) {
            proceed = NO;
        }
        
        if(proceed) {
            NSMutableArray *photos = [[NSMutableArray alloc] init];
            [photos addObject:[MWPhoto photoWithURL:[NSURL URLWithString:src]]];
            
            MWPhotoBrowser *browser = [[MWPhotoBrowser alloc] initWithPhotos:photos];
            
            UIViewController *vc = ApplicationDelegate.window.rootViewController;
            UINavigationController *navi = [[UINavigationController alloc] initWithRootViewController:browser];
            [vc presentModalViewController:navi animated:YES];
            
        }
    }
}

-(void)didFullscreenGesture : (UIGestureRecognizer *)gesture
{
    if([gesture state] == UIGestureRecognizerStateRecognized) {
        self.isFullScreen = !self.isFullScreen;
        
        if(self.isFullScreen) {
            [self.navigationController setNavigationBarHidden:YES animated:YES];
            [self.navigationController setToolbarHidden:YES animated:YES];
        } else {
            [self.navigationController setNavigationBarHidden:NO animated:YES];
            [self.navigationController setToolbarHidden:NO animated:YES];
        }
    }
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.isFullScreen = NO;
    
    UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(heldPost:)];
    press.delegate = self;
    press.minimumPressDuration = 0.3;
    [self.webView addGestureRecognizer:press];
    self.webViewDelegateWrapper = [AwfulWebViewDelegateWrapper delegateWrappingDelegate:self];
    self.webView.delegate = self.webViewDelegateWrapper;
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(didFullscreenGesture:)];
        [self.webView addGestureRecognizer:pinch];
        pinch.delegate = self;
    }
    
    [self.pagesBarButtonItem setTintColor:[UIColor darkGrayColor]];
}

@synthesize webViewDelegateWrapper = _webViewDelegateWrapper;

- (void)viewDidUnload
{
    [self.networkOperation cancel];
    [self.webView stopLoading];
    [super viewDidUnload];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setToolbarHidden:NO];
    self.navigationController.toolbar.barStyle = UIBarStyleBlack;
}

- (void)viewDidDisappear:(BOOL)animated
{
    // Blank the web view if we're leaving for good. Otherwise we get weirdness like videos
    // continuing to play their sound after the user switches to a different thread.
    if (!self.navigationController) {
        NSURL *blank = [NSURL URLWithString:@"about:blank"];
        [self.webView loadRequest:[NSURLRequest requestWithURL:blank]];
    }
    [super viewDidDisappear:animated];
}

#pragma mark - BarButtonItem Actions

-(void)updatePagesLabel
{
    self.pagesBarButtonItem.title = [NSString stringWithFormat:@"Page %d of %d", self.currentPage, self.numberOfPages];
    if(self.currentPage == self.numberOfPages) {
        [self.pagesSegmentedControl setEnabled:NO forSegmentAtIndex:1];
    } else {
        [self.pagesSegmentedControl setEnabled:YES forSegmentAtIndex:1];
    }
    if(self.currentPage == 1) {
        [self.pagesSegmentedControl setEnabled:NO forSegmentAtIndex:0];
    } else {
        [self.pagesSegmentedControl setEnabled:YES forSegmentAtIndex:0];
    }
}

- (void)updateBookmarked
{
    [self.thread setIsBookmarked:[NSNumber numberWithBool:self.dataController.bookmarked]];
}

-(IBAction)segmentedGotTapped : (id)sender
{
    if(sender == self.actionsSegmentedControl) {
        [self tappedActionsSegment:nil];
    } else if(sender == self.pagesSegmentedControl) {
        [self tappedPagesSegment:nil];
    }
}

-(IBAction)tappedPagesSegment : (id)sender
{
    if(self.pagesSegmentedControl.selectedSegmentIndex == 0) {
        [self prevPage];
    } else if(self.pagesSegmentedControl.selectedSegmentIndex == 1) {
        [self nextPage];
    }
    self.pagesSegmentedControl.selectedSegmentIndex = -1;
}

-(IBAction)tappedActionsSegment : (id)sender
{
    if(self.actionsSegmentedControl.selectedSegmentIndex == 0) {
        [self tappedActions:nil];
    } else if(self.actionsSegmentedControl.selectedSegmentIndex == 1) {
        [self tappedCompose:nil];
    }
    self.actionsSegmentedControl.selectedSegmentIndex = -1;
}

-(IBAction)tappedNextPage : (id)sender
{
    [self nextPage];
}

-(void)nextPage
{
    self.pullForActionController.footerState = AwfulPullForActionStateLoading;
    
    return;
    if(self.currentPage < self.numberOfPages) {
        self.destinationType = AwfulPageDestinationTypeSpecific;
        [self loadPageNum:self.currentPage + 1];
    }
}

-(void)prevPage
{
    if(self.currentPage > 1) {
        self.destinationType = AwfulPageDestinationTypeSpecific;
        [self loadPageNum:self.currentPage - 1];
    }
}

-(IBAction)tappedActions:(id)sender
{
    self.actions = [[AwfulThreadActions alloc] initWithThread:self.thread];
    self.actions.viewController = self;
    [self.actions showFromToolbar:self.navigationController.toolbar];
}

-(void)tappedPageNav : (id)sender
{
    if(self.numberOfPages <= 0 || self.currentPage <= 0) {
        return;
    }
    
    UIView *sp_view = self.specificPageController.containerView;
    
    if(self.specificPageController != nil && !self.specificPageController.hiding) {
        
        [self.pagesBarButtonItem setTintColor:[UIColor darkGrayColor]];
        self.specificPageController.hiding = YES;
        [UIView animateWithDuration:0.3 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^(void) {
            sp_view.frame = CGRectOffset(sp_view.frame, 0, sp_view.frame.size.height);
        } completion:^(BOOL finished) {
            [sp_view removeFromSuperview];
            self.specificPageController = nil;
        }];
        
    } else if(self.specificPageController == nil) {
        
        [self.pagesBarButtonItem setTintColor:[UIColor blackColor]];
        self.specificPageController = [self.storyboard instantiateViewControllerWithIdentifier:@"AwfulSpecificPageController"];
        self.specificPageController.page = self;
        [self.specificPageController loadView];
        sp_view = self.specificPageController.containerView;
        sp_view.frame = CGRectMake(0, self.view.frame.size.height, self.view.frame.size.width, sp_view.frame.size.height);
        
        [self.view addSubview:sp_view];
        [UIView animateWithDuration:0.3 animations:^(void) {
            sp_view.frame = CGRectOffset(sp_view.frame, 0, -sp_view.frame.size.height+40);
        }];
        
        [self.specificPageController.pickerView selectRow:self.currentPage - 1
                                              inComponent:0
                                                 animated:NO];
    }
}
       
-(void)hidePageNavigation
{
    if(self.specificPageController != nil) {
        [self tappedPageNav:nil];
    }
}

-(IBAction)tappedCompose : (id)sender
{
    [self performSegueWithIdentifier:@"ReplyBox" sender:self];
}

#pragma mark - Navigator Content

-(void)scrollToBottom
{
    [self.webView stringByEvaluatingJavaScriptFromString:@"window.scrollTo(0, document.body.scrollHeight);"];
}

-(void)scrollToSpecifiedPost
{
    [self scrollToPost:self.postIDScrollDestination];
}

-(void)scrollToPost : (NSString *)post_id
{
    if(post_id != nil) {
        NSString *scrolling = [NSString stringWithFormat:@"scrollToID('%@')", post_id];
        [self.webView stringByEvaluatingJavaScriptFromString:scrolling];
    }
}

-(void)showActions:(NSString *)post_id fromRect:(CGRect)rect
{
    self.actions = nil;
    if (!post_id || post_id.length == 0)
        return;
    for (AwfulPost *post in self.dataController.posts) {
        if([post.postID isEqualToString:post_id]) {
            self.actions = [[AwfulPostActions alloc] initWithAwfulPost:post
                                                                  page:self];
            break;
        }
    }
    self.actions.viewController = self;
    [self.actions showFromRect:rect inView:[self.view superview] animated:YES];
}

-(void)showActions
{
    self.actions.viewController = self;
    [self.actions showFromToolbar:self.navigationController.toolbar];
}

#pragma mark - AwfulWebViewDelegate

- (void)webView:(UIWebView *)webView
pageDidRequestAction:(NSString *)action
 infoDictionary:(NSDictionary *)infoDictionary
{
    if ([action isEqualToString:@"nextPage"]) {
        return [self nextPage];
    }
    if ([action isEqualToString:@"loadOlderPosts"]) {
        return [self loadOlderPosts];
    }
    if ([action isEqualToString:@"postOptions"]) {
        NSString *postID = [infoDictionary objectForKey:@"postID"];
        CGRect rect = CGRectZero;
        if ([infoDictionary objectForKey:@"rect"])
            rect = CGRectFromString([infoDictionary objectForKey:@"rect"]);
        return [self showActions:postID fromRect:rect];
    }
}

#pragma mark - Gesture Delegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

#pragma mark - Web View Delegate

- (BOOL)webView:(UIWebView *)webView
shouldStartLoadWithRequest:(NSURLRequest *)request
 navigationType:(UIWebViewNavigationType)navigationType
{    
    if(navigationType == UIWebViewNavigationTypeLinkClicked) {
        
        NSURL *open_url = request.URL;
        
        if([[request.URL host] isEqualToString:@"forums.somethingawful.com"] &&
           [[request.URL lastPathComponent] isEqualToString:@"showthread.php"]) {
            
            NSString *thread_id = nil;
            NSString *page_number = nil;
            
            NSArray *query_elements = [[request.URL query] componentsSeparatedByString:@"&"];
            for(NSString *element in query_elements) {
                NSArray *key_and_val = [element componentsSeparatedByString:@"="];
                if([[key_and_val objectAtIndex:0] isEqualToString:@"threadid"]) {
                    thread_id = [key_and_val lastObject];
                } else if([[key_and_val objectAtIndex:0] isEqualToString:@"pagenumber"]) {
                    page_number = [key_and_val lastObject];
                }
            }
            
            if(thread_id != nil) {
                NSManagedObjectContext *moc = ApplicationDelegate.throwawayObjectContext;
                AwfulThread *intra = [AwfulThread insertInManagedObjectContext:moc];
                intra.threadID = thread_id;
                
                AwfulPage *page = [self.storyboard instantiateViewControllerWithIdentifier:@"AwfulPage"];
                page.thread = intra;
                [self.navigationController pushViewController:page animated:YES];
                if(page_number != nil) {
                    page.destinationType = AwfulPageDestinationTypeSpecific;
                    [page loadPageNum:[page_number integerValue]];
                } else {
                    page.destinationType = AwfulPageDestinationTypeFirst;
                    [page refresh];
                }
                return NO;
            }
            
            
        } else if([[request.URL host] isEqualToString:@"itunes.apple.com"] || [[request.URL host] isEqualToString:@"phobos.apple.com"])  {
            [[UIApplication sharedApplication] openURL:request.URL];
            return NO;
        } else if([request.URL host] == nil && [[request.URL lastPathComponent] isEqualToString:@"showthread.php"]) {
            open_url = [NSURL URLWithString:[NSString stringWithFormat:@"http://forums.somethingawful.com/%@", request.URL]];
        }
        
        OtherWebController *other = [[OtherWebController alloc] initWithURL:open_url];
        UINavigationController *other_nav = [[UINavigationController alloc] initWithRootViewController:other];
        other_nav.navigationBar.barStyle = UIBarStyleBlack;
        [other_nav setToolbarHidden:NO];
        other_nav.toolbar.barStyle = UIBarStyleBlack;
        
        UIViewController *vc = ApplicationDelegate.window.rootViewController;
        [vc presentModalViewController:other_nav animated:YES];
        
        return NO;
    }
    return YES;
}

-(void)webViewDidFinishLoad:(UIWebView *)sender
{
    //[self.webView.scrollView setContentOffset:CGPointMake(0, 0) animated:NO];
    [self swapToRefreshButton];
    if(self.postIDScrollDestination != nil) {
        [self scrollToSpecifiedPost];
    } else if(self.shouldScrollToBottom) {
        [self scrollToBottom];
    }
    
    self.pullForActionController.headerState = AwfulPullForActionStateNormal;
    self.pullForActionController.footerState = AwfulPullForActionStateNormal;
    
    //animate old page up and offscreen, new page in from the bottom
    if (sender == self.nextPageWebView) {
        [self doPageTransition];
        
    }
    else {
        [UIView animateWithDuration:.5 animations:^{
            self.webView.scrollView.contentInset = UIEdgeInsetsZero;
        }
         ];
    }
}
/*
-(void) awfulFooterDidTriggerLoad:(AwfulLoadingFooterView*)pullToNavigate {
    [self tappedNextPage:nil];
}
*/
-(void)webViewDidStartLoad:(UIWebView *)webView
{
    
}

-(void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
}

-(void)swapToRefreshButton
{
    UIBarButtonItem *refresh = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(hardRefresh)];
    refresh.style = UIBarButtonItemStyleBordered;
    self.navigationItem.rightBarButtonItem = refresh;
}

-(void)swapToStopButton
{
    UIBarButtonItem *stop = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(stop)];
    stop.style = UIBarButtonItemStyleBordered;
    self.navigationItem.rightBarButtonItem = stop;
}

-(void)showCompletionMessage : (NSString *)message
{
    dispatch_async(dispatch_get_main_queue(), ^(){
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:NO];
        hud.labelText = message;
        hud.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Checkmark"]];
        hud.mode = MBProgressHUDModeCustomView;
        [UIView animateWithDuration:0.5 delay:2.0 options:UIViewAnimationOptionCurveEaseIn animations:^(void){
            hud.alpha = 0.0;
        } completion:^(BOOL finished) {
            [MBProgressHUD hideHUDForView:self.view animated:NO];
        }];
    });
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return YES;
    }
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

-(void) didSwitchAutoF5:(UISwitch *)switchObj {
    if (switchObj.on) {
        self.autoRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:20 
                                                                 target:self
                                                               selector:@selector(timerDidFire:)
                                                               userInfo:nil
                                                                repeats:YES];
    }   
    else {
        [self.autoRefreshTimer invalidate];
        self.autoRefreshTimer = nil;
    }
}

-(void) timerDidFire:(NSTimer*)timer {
    NSLog(@"timer fired");
    [self refresh];
    //check if we're still on the last page
    //if there's a new page invalidate timer, set footer as not on last page
}

#pragma mark Pull For Action
-(void) didPullHeader:(UIView<AwfulPullForActionViewDelegate>*)header {
    [self refresh];
}

-(void) didPullFooter:(UIView<AwfulPullForActionViewDelegate>*)footer {
    [self tappedNextPage:nil];
}

-(void) didCancelPullForAction:(AwfulPullForActionController *)pullForActionController {
    [self stop];
    pullForActionController.headerState ^= AwfulPullForActionStateLoading;
    pullForActionController.footerState ^= AwfulPullForActionStateLoading;
}

@end

@implementation AwfulPageIpad
@synthesize popController = _popController;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    tap.delegate = self;
    [self.webView addGestureRecognizer:tap];
}

-(IBAction)tappedPageNav : (id)sender
{
    if(self.popController)
    {
        [self.popController dismissPopoverAnimated:YES];
        self.popController = nil;
    }
    
    if(self.numberOfPages <= 0 || self.currentPage <= 0)
    {
        return;
    }
    
    UIView *sp_view = self.specificPageController.containerView;
        
    if(self.specificPageController == nil) {
        
        self.specificPageController = [[UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"AwfulSpecificPageController"];
        self.specificPageController.page = self;
        [self.specificPageController loadView];
        sp_view = self.specificPageController.containerView;
        
        [self.specificPageController.pickerView selectRow:self.currentPage - 1
                                              inComponent:0
                                                 animated:NO];
    }

    UIViewController *vc = self.specificPageController;

    self.popController = [[UIPopoverController alloc] initWithContentViewController:vc];
    
    [self.popController setPopoverContentSize:CGSizeMake(260,sp_view.frame.size.height) animated:YES];
    [self.popController presentPopoverFromBarButtonItem:self.pagesBarButtonItem 
                               permittedArrowDirections:UIPopoverArrowDirectionAny
                                               animated:YES];
}


- (void)showRootPopoverButtonItem:(UIBarButtonItem *)barButtonItem {

    [self.navigationItem setLeftBarButtonItem:barButtonItem animated:YES];
}


- (void)invalidateRootPopoverButtonItem:(UIBarButtonItem *)barButtonItem {
    
    [self.navigationItem setLeftBarButtonItem:nil animated:YES];
}

- (void)handleTap:(UITapGestureRecognizer *)sender 
{     
    if (sender.state == UIGestureRecognizerStateEnded)     
    {         // handling code     
        _lastTouch = [sender locationInView:self.view];
    } 
}

// hack for embedded youtube controls to work
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    if([gestureRecognizer isKindOfClass:[UITapGestureRecognizer class]]) {
        CGPoint loc = [touch locationInView:self.view];
        _lastTouch = loc;
        return NO;
    }
    return YES;
}

-(IBAction)tappedActions:(id)sender
{
    self.actions = [[AwfulThreadActions alloc] initWithThread:self.thread];
    [self showActions];
}

-(void)showActions
{    
    self.actions.viewController = self;
    UIActionSheet *sheet = self.actions.actionSheet;
    CGRect buttonRect;
    if ([self.actions isKindOfClass:[AwfulThreadActions class]] || [self.actions isKindOfClass:[AwfulVoteActions class]])
    {
        buttonRect = self.actionsSegmentedControl.frame;
        buttonRect.origin.y += self.view.frame.size.height;  //Add the height of the view to the button y
        buttonRect.size.width = buttonRect.size.width / 2;   //Action is the first button, so the width is really only half
    } else {
        NSLog(@"only thread actions and vote actions are supported by this 'showActions' method");
        return;
    }
    [sheet showFromRect:buttonRect inView:self.view animated:YES];
}

- (void)showActions:(NSString *)post_id fromRect:(CGRect)rect
{
    self.actions = nil;
    if (!post_id || post_id.length == 0)
        return;
    for (AwfulPost *post in self.dataController.posts) {
        if([post.postID isEqualToString:post_id]) {
            self.actions = [[AwfulPostActions alloc] initWithAwfulPost:post
                                                                  page:self];
            break;
        }
    }
    if(self.popController)
    {
        [self.popController dismissPopoverAnimated:YES];
        self.popController = nil;
    }
    if (!self.actions)
        return;
    self.actions.viewController = self;
    UIActionSheet *sheet = self.actions.actionSheet;
    CGRect buttonRect = rect;
    if ([self.actions isKindOfClass:[AwfulThreadActions class]] || [self.actions isKindOfClass:[AwfulVoteActions class]])
    {
        buttonRect = self.actionsSegmentedControl.frame;
        buttonRect.origin.y += self.view.frame.size.height;  //Add the height of the view to the button y
        buttonRect.size.width = buttonRect.size.width / 2;   //Action is the first button, so the width is really only half
    }
    [sheet showFromRect:buttonRect inView:self.view animated:YES];
}

-(IBAction)tappedCompose : (id)sender
{
        //Hide any popovers if composed pressed
    if(self.popController)
    {
        [self.popController dismissPopoverAnimated:YES];
        self.popController = nil;
    }
    
    [super tappedCompose:sender];
}

-(void)hidePageNavigation
{
    if(self.popController) {
        [self.popController dismissPopoverAnimated:YES];
        self.popController = nil;
    }
}
@end
