//
//  AwfulPage.m
//  Awful
//
//  Created by Sean Berry on 7/29/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulThreadList.h"
#import "AwfulAppDelegate.h"
#import "AwfulPage.h"
#import "TFHpple.h"
#import "AwfulPost.h"
#import "AwfulUtil.h"
#import "OtherWebController.h"
#import "AwfulParse.h"
#import "AwfulPageRefreshRequest.h"
#import "ASIFormDataRequest.h"
#import "AwfulQuoteRequest.h"
#import "AwfulReplyRequest.h"
#import "AwfulEditRequest.h"
#import "Appirater.h"
#import "AwfulPageCount.h"
#import "AwfulConfig.h"
#import "AwfulNavigator.h"
#import "AwfulNavigatorLabels.h"
#import "AwfulThreadActions.h"
#import "AwfulHistoryManager.h"
#import "AwfulHistory.h"
#import "AwfulPostActions.h"
#import "AwfulRequestHandler.h"
#import "MWPhoto.h"
#import "MWPhotoBrowser.h"
#import <QuartzCore/QuartzCore.h>
#import "AwfulUser.h"
#import "AwfulSmallPageController.h"
#import "AwfulExtrasController.h"
#import "AwfulSplitViewController.h"
#import "AwfulLoginController.h"

@implementation AwfulPage

@synthesize thread = _thread;
@synthesize url = _url;
@synthesize destinationType = _destinationType;
@synthesize isBookmarked = _isBookmarked;
@synthesize allRawPosts = _allRawPosts;
@synthesize pagesLabel = _pagesLabel;
@synthesize threadTitleLabel = _threadTitleLabel;
@synthesize pagesButton = _pagesButton;
@synthesize pages = _pages;
@synthesize delegate = _delegate;
@synthesize forumButton = _forumButton;
@synthesize shouldScrollToBottom = _shouldScrollToBottom;
@synthesize scrollToPostID = _scrollToPostID;
@synthesize touchedPage = _touchedPage;
@synthesize adHTML = _adHTML;
@synthesize pageController = _pageController;

#pragma mark -
#pragma mark Initialization

-(id)initWithAwfulThread : (AwfulThread *)thread startAt : (AwfulPageDestinationType)thread_pos
{
    return [self initWithAwfulThread:thread startAt:thread_pos pageNum:-1];
}

-(id)initWithAwfulThread : (AwfulThread *)thread pageNum : (int)page_num
{
    return [self initWithAwfulThread:thread startAt:AwfulPageDestinationTypeSpecific pageNum:page_num];
}

-(id)initWithAwfulThread : (AwfulThread *)thread startAt : (AwfulPageDestinationType)thread_pos pageNum : (int)page_num
{
    if((self = [super initWithNibName:nil bundle:nil])) {
        _thread = [thread retain];
        _pages = nil;
        _shouldScrollToBottom = NO;
        _scrollToPostID = nil;
        _touchedPage = NO;
        _destinationType = thread_pos;
        
        _allRawPosts = [[NSMutableArray alloc] init];
        
        NSString *append;
        switch(thread_pos) {
            case AwfulPageDestinationTypeFirst:
                append = @"";
                break;
            case AwfulPageDestinationTypeLast:
                append = @"&goto=lastpost";
                _shouldScrollToBottom = YES;
                break;
            case AwfulPageDestinationTypeNewpost:
                append = @"&goto=newpost";
                break;
            case AwfulPageDestinationTypeSpecific:
                append = [NSString stringWithFormat:@"&pagenumber=%d", page_num];
                break;
            default:
                append = @"";
                break;
        }
        
        _url = [[NSString alloc] initWithFormat:@"showthread.php?threadid=%@%@", _thread.threadID, append];
        
        _isBookmarked = NO;
        NSMutableArray *bookmarked_threads = [AwfulUtil newThreadListForForumId:@"bookmarks"];
        for(AwfulThread *thread in bookmarked_threads) {
            if([thread.threadID isEqualToString:_thread.threadID]) {
                _isBookmarked = YES;
            }
        }
        [bookmarked_threads release];
    }
    return self;
}

- (void)dealloc {
    [_url release];
    [_thread release];
    [_allRawPosts release];
    [_pagesLabel release];
    [_threadTitleLabel release];
    [_pagesButton release];
    [_forumButton release];
    [_pages release];
    [_scrollToPostID release];
    [_adHTML release];
    [_pageController release];
    
    [super dealloc];
}

-(void)setWebView:(JSBridgeWebView *)webView;
{
    UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(heldPost:)];
    press.delegate = self;
    press.minimumPressDuration = 0.3;
    [webView addGestureRecognizer:press];
    [press release];
    
    AwfulNavigator *nav = getNavigator();
    UITapGestureRecognizer *three_times = [[UITapGestureRecognizer alloc] initWithTarget:nav action:@selector(didFullscreenGesture:)];
    three_times.numberOfTapsRequired = 3;
    three_times.delegate = self;
    [webView addGestureRecognizer:three_times];
    [three_times release];
    
    UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:nav action:@selector(didFullscreenGesture:)];
    [webView addGestureRecognizer:pinch];
    pinch.delegate = self;
    [pinch release];
    
    webView.delegate = self;
    self.view = webView;
    nav.view = self.view;
    if([nav isFullscreen]) {
        nav.fullScreenButton.center = CGPointMake(nav.view.frame.size.width-25, nav.view.frame.size.height-25);
        [nav.view addSubview:nav.fullScreenButton];
    }
}

-(NSString *)getURLSuffix
{
    if(self.pages == nil) {
        return self.url;
    }
    return [NSString stringWithFormat:@"showthread.php?threadid=%@&pagenumber=%d", self.thread.threadID, self.pages.currentPage];
}

-(void)setPages:(AwfulPageCount *)pages
{
    if(_pages != pages) {
        [_pages release];
        _pages = [pages retain];
        self.pagesLabel.text = [pages description];
        [self.pagesButton setTitle:[self.pages description] forState:UIControlStateNormal];
        [self.pagesButton setTitle:[self.pages description] forState:UIControlStateSelected];
        
        // lame workaround - history doesn't know my pageNum right away
        AwfulNavigator *nav = getNavigator();
        AwfulHistory *my_history = [nav.historyManager.recordedHistory lastObject];
        my_history.pageNum = _pages.currentPage;
    }
}

-(void)setThreadTitle : (NSString *)in_title
{
    [self.thread setTitle:in_title];
    [self.threadTitleLabel setText:in_title];
}

-(void)tappedPageNav : (id)sender
{
    if(self.pageController != nil && !self.pageController.hiding) {
        self.pageController.hiding = YES;
        [UIView animateWithDuration:0.3 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^(void) {
            self.pageController.view.frame = CGRectOffset(self.pageController.view.frame, 0, -self.pageController.view.frame.size.height);
        } completion:^(BOOL finished) {
            [self.pageController.view removeFromSuperview];
            self.pageController = nil;
        }];
    } else if(self.pageController == nil) {
        self.pageController = [[[AwfulSmallPageController alloc] initWithAwfulPage:self] autorelease];
        
        float width_diff = self.view.frame.size.width - self.pageController.view.frame.size.width;
        self.pageController.view.center = CGPointMake(self.view.center.x + width_diff/2, -self.pageController.view.frame.size.height/2);
        [self.view addSubview:self.pageController.view];
        [UIView animateWithDuration:0.3 animations:^(void) {
            self.pageController.view.frame = CGRectOffset(self.pageController.view.frame, 0, self.pageController.view.frame.size.height);
        }];
    }
}

-(void)hardRefresh
{    
    int posts_per_page = getPostsPerPage();
    if([self.pages onLastPage] && [self.allRawPosts count] == posts_per_page) {
        
        AwfulPage *current_page = [[AwfulPage alloc] initWithAwfulThread:self.thread startAt:AwfulPageDestinationTypeSpecific pageNum:self.pages.currentPage];
        current_page.shouldScrollToBottom = YES;
        loadContentVC(current_page);
        [current_page release];
        
    } else {
        
        AwfulPage *fresh_page = [[AwfulPage alloc] initWithAwfulThread:self.thread startAt:AwfulPageDestinationTypeNewpost];
        loadContentVC(fresh_page);
        [fresh_page release];
    }
}

-(void)refresh
{    
    [self.delegate swapToStopButton];
    AwfulPageRefreshRequest *ref_req = [[AwfulPageRefreshRequest alloc] initWithAwfulPage:self];
    loadRequestAndWait(ref_req);
    [ref_req release];
}

-(void)stop
{
    AwfulNavigator *nav = getNavigator();
    [nav.requestHandler cancelAllRequests];
    
    if([self.view isMemberOfClass:[UIWebView class]]) {
        [(UIWebView *)self.view stopLoading];
    }
}

-(void)loadOlderPosts
{
    int pages_left = self.pages.totalPages - self.pages.currentPage;
    NSString *html = [AwfulParse constructPageHTMLFromPosts:self.allRawPosts pagesLeft:pages_left numOldPosts:0 adHTML:self.adHTML];
    
    AwfulNavigator *nav = getNavigator();
    JSBridgeWebView *web = [[JSBridgeWebView alloc] initWithFrame:nav.view.frame];
    [web loadHTMLString:html baseURL:[NSURL URLWithString:@"http://forums.somethingawful.com"]];
    web.delegate = self;
    [self setWebView:web];
    [web release];
    nav.view = self.view;
}

-(void)acceptPosts : (NSMutableArray *)posts
{    
    self.allRawPosts = posts;
}

-(void)nextPage
{
    if(![self.pages onLastPage]) {
        AwfulPage *next_page = [[AwfulPage alloc] initWithAwfulThread:self.thread startAt:AwfulPageDestinationTypeSpecific pageNum:self.pages.currentPage+1];
        loadContentVC(next_page);
        [next_page release];
    }
}

-(void)prevPage
{
    if(self.pages.currentPage > 1) {
        AwfulPage *prev_page = [[AwfulPage alloc] initWithAwfulThread:self.thread startAt:AwfulPageDestinationTypeSpecific pageNum:self.pages.currentPage-1];
        loadContentVC(prev_page);
        [prev_page release];
    }
}

-(void)heldPost:(UILongPressGestureRecognizer *)gestureRecognizer
{    
    UIWebView *web = (UIWebView *)self.view;
    CGPoint p = [gestureRecognizer locationInView:self.view];
    NSString *offset_str = [(UIWebView *)self.view stringByEvaluatingJavaScriptFromString:@"scrollY"];
    float offset = [offset_str intValue];
    
    // if iOS 5.0, I don't need the offset
    if([web respondsToSelector:@selector(scrollView)]) {
        offset = 0.0;
    }
    
    NSString *js_tag_name = [NSString stringWithFormat:@"document.elementFromPoint(%f, %f).tagName", p.x, p.y+offset];
    NSString *tag_name = [(UIWebView *)self.view stringByEvaluatingJavaScriptFromString:js_tag_name];
    if([tag_name isEqualToString:@"IMG"]) {
        NSString *js_src = [NSString stringWithFormat:@"document.elementFromPoint(%f, %f).src", p.x, p.y+offset];
        NSString *src = [(UIWebView *)self.view stringByEvaluatingJavaScriptFromString:js_src];
        NSString *js_class = [NSString stringWithFormat:@"document.elementFromPoint(%f, %f).className", p.x, p.y+offset];
        NSString *class = [(UIWebView *)self.view stringByEvaluatingJavaScriptFromString:js_class];
        
        BOOL proceed = YES;
        
        if([class isEqualToString:@"postaction"]) {
            proceed = NO;
        }
        
        if(proceed) {
            for(AwfulPost *post in self.allRawPosts) {
                if([[post.avatarURL absoluteString] isEqualToString:src]) {
                    proceed = NO;
                }
            }
        }
        
        if(proceed) {
            NSMutableArray *photos = [[NSMutableArray alloc] init];
            [photos addObject:[MWPhoto photoWithURL:[NSURL URLWithString:src]]];
            
            MWPhotoBrowser *browser = [[MWPhotoBrowser alloc] initWithPhotos:photos];
            
            UIViewController *vc = getRootController();
            UINavigationController *navi = [[UINavigationController alloc] initWithRootViewController:browser];
            [vc presentModalViewController:navi animated:YES];
            [navi release];
            
            [browser release];
            [photos release];
        }
    }
}

-(void)scrollToPost : (NSString *)post_id
{
    if(post_id != nil) {
        NSString *scrolling = [NSString stringWithFormat:@"scrollToID(%@)", post_id];
        [(UIWebView *)self.view stringByEvaluatingJavaScriptFromString:scrolling];
    }
}

/*
 - (void)viewWillAppear:(BOOL)animated {
 [super viewWillAppear:animated];
 }
 */
/*
 - (void)viewDidAppear:(BOOL)animated {
 [super viewDidAppear:animated];
 }
 */
/*
 - (void)viewWillDisappear:(BOOL)animated {
 [super viewWillDisappear:animated];
 }
 */
/*
 - (void)viewDidDisappear:(BOOL)animated {
 [super viewDidDisappear:animated];
 }
 */
/*
 // Override to allow orientations other than the default portrait orientation.
 - (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
 // Return YES for supported orientations
 return (interfaceOrientation == UIInterfaceOrientationPortrait);
 }
 */

/*
 -(void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
 {
 
 }*/

/*
 - (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
 {
 
 }*/

#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Relinquish ownership any cached data, images, etc that aren't in use.
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    AwfulNavigatorLabels *labels = [[AwfulNavigatorLabels alloc] init];
    self.threadTitleLabel = labels.threadTitleLabel;
    [labels release];
    
    UIView *label_container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, getWidth()-100, 44)];
    [label_container setBackgroundColor:[UIColor clearColor]];
    [label_container addSubview:self.threadTitleLabel];
    label_container.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.threadTitleLabel.frame = CGRectMake(0, 0, label_container.frame.size.width, label_container.frame.size.height);
    
    self.threadTitleLabel.text = self.thread.title;
    self.delegate.navigationItem.titleView = label_container;
    [label_container release];
    
    self.pagesButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.pagesButton.titleLabel.lineBreakMode = UILineBreakModeWordWrap;
    [self.pagesButton addTarget:self action:@selector(tappedPageNav:) forControlEvents:UIControlEventTouchUpInside];
    [self.pagesButton setBackgroundImage:[UIImage imageNamed:@"grey-gradient.png"] forState:UIControlStateNormal];
    self.pagesButton.titleLabel.font = [UIFont fontWithName:@"Helvetica" size:12.0f];
    [self.pagesButton.layer setCornerRadius:4.0f];
    [self.pagesButton.layer setMasksToBounds:YES];
    [self.pagesButton.layer setBorderWidth:1.2f];
    [self.pagesButton.layer setBorderColor: [[UIColor colorWithWhite:0.2 alpha:1.0] CGColor]];
    
    float pages_button_height = 38.0;
    if(UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation])) {
        pages_button_height = 28.0;
    }
    self.pagesButton.frame = CGRectMake(0.0, 0.0, 44.0, pages_button_height);
    self.pagesButton.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    [self.pagesButton setTitle:[self.pages description] forState:UIControlStateNormal];
    [self.pagesButton setTitle:[self.pages description] forState:UIControlStateSelected];
    
    
    UIBarButtonItem *cust = [[UIBarButtonItem alloc] initWithCustomView:self.pagesButton];
    self.delegate.navigationItem.rightBarButtonItem = cust;
    [cust release];
    
    self.title = self.thread.title;
}

- (void)viewDidUnload {
    // Relinquish ownership of anything that can be recreated in viewDidLoad or on demand.
    // For example: self.myOutlet = nil;
    self.pagesLabel = nil;
    self.threadTitleLabel = nil;
    self.forumButton = nil;
    self.pagesButton = nil;
}

#pragma mark -
#pragma mark AwfulHistoryRecorder

-(id)newRecordedHistory
{
    AwfulHistory *hist = [[AwfulHistory alloc] init];
    hist.pageNum = self.pages.currentPage;
    hist.modelObj = self.thread;
    hist.historyType = AwfulHistoryTypePage;
    return hist;
}

-(id)initWithAwfulHistory : (AwfulHistory *)history
{
    return [self initWithAwfulThread:history.modelObj pageNum:history.pageNum];
}

#pragma mark -
#pragma mark Navigator Contnet

-(UIView *)getView
{
    return self.view;
}

-(AwfulActions *)getActions
{
    return [[[AwfulThreadActions alloc] initWithAwfulPage:self] autorelease];
}

-(void)scrollToBottom
{
    [(UIWebView *)self.view stringByEvaluatingJavaScriptFromString:@"window.scrollTo(0, document.body.scrollHeight);"];
}

-(void)scrollToSpecifiedPost
{
    [self scrollToPost:self.scrollToPostID];
}

#pragma mark JSBBridgeWebDelegate

- (void)webView:(UIWebView*) webview didReceiveJSNotificationWithDictionary:(NSDictionary*) dictionary
{
    //NSLog(@"%@", dictionary);
    NSString *action = [dictionary objectForKey:@"action"];
    if(action != nil) {
        if([action isEqualToString:@"nextPage"]) {
            [self nextPage];
        } else if([action isEqualToString:@"loadOlderPosts"]) {
            [self loadOlderPosts];
        } else if([action isEqualToString:@"postOptions"]) {
            
            AwfulNavigator *nav = getNavigator();
            NSString *post_id = [dictionary objectForKey:@"postid"];
            
            if(![post_id isEqualToString:@""] && nav.actions == nil) {
                for(AwfulPost *post in self.allRawPosts) {
                    if([post.postID isEqualToString:post_id]) {
                        AwfulPostActions *actions = [[AwfulPostActions alloc] initWithAwfulPost:post page:self];
                        [nav setActions:actions];
                        [actions release];
                    }
                }
            }
        }
    }
}

-(void)didScroll
{
    self.touchedPage = YES;
}

#pragma mark Gesture Delegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

#pragma mark Web View Delegate

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
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
                AwfulThread *intra = [[AwfulThread alloc] init];
                intra.threadID = thread_id;
                
                AwfulPage *page = nil;
                
                if(page_number == nil) {
                    page = [[AwfulPage alloc] initWithAwfulThread:intra startAt:AwfulPageDestinationTypeFirst];
                } else {
                    page = [[AwfulPage alloc] initWithAwfulThread:intra startAt:AwfulPageDestinationTypeSpecific pageNum:[page_number intValue]];
                    int pti = [AwfulParse getNewPostNumFromURL:request.URL];
                    page.url = [NSString stringWithFormat:@"showthread.php?threadid=%@&pagenumber=%@#pti%d", thread_id, page_number, pti];
                }
                
                [intra release];
                
                if(page != nil) {
                    loadContentVC(page);
                    [page release];
                    return NO;
                }
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
        [other release];
        
        UIViewController *vc = getRootController();
        [vc presentModalViewController:other_nav animated:YES];
        [other_nav release];
        
        return NO;
    }
    return YES;
}

-(void)webViewDidFinishLoad:(UIWebView *)sender
{
    [self.delegate swapToRefreshButton];
    if(!self.touchedPage) {
        if(self.scrollToPostID != nil) {
            [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(scrollToSpecifiedPost) userInfo:nil repeats:NO];
        } else if(self.shouldScrollToBottom) {
            [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(scrollToBottom) userInfo:nil repeats:NO];
        }
    }
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
}

@end


#pragma mark -
#pragma mark AwfulPageIpad
@implementation AwfulPageIpad : AwfulPage
@synthesize pageButton = _pageButton;
@synthesize popController = _popController;
@synthesize pagePicker = _pagePicker;

- (void) viewDidLoad
{
    [super viewDidLoad];
    [self makeCustomToolbars];
    [self setThreadTitle:self.thread.title];
}

-(void)makeCustomToolbars
{
    UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 140, 40)];
    NSMutableArray *items = [NSMutableArray array];
    
    UIBarButtonItem *act = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(hitActions)];
    UIBarButtonItem *more = [[UIBarButtonItem alloc] initWithTitle:@"..." style:UIBarButtonItemStylePlain target:self action:@selector(hitMore)];
    UIBarButtonItem *space = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    
    [items addObject:space];    
    if (isLoggedIn())
    {
        [items addObject:act];
    }
    [items addObject:more];
    
    [toolbar setItems:items];
    
    [act release];
    [more release];
    [space release];
    UIBarButtonItem *toolbar_cust = [[UIBarButtonItem alloc] initWithCustomView:toolbar];
    [toolbar release];
    self.navigationItem.rightBarButtonItem = toolbar_cust;
    [toolbar_cust release];
    
    items = [NSMutableArray array];
    
    UIBarButtonItem *refresh = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(hardRefresh)];
    
    space = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    
    UIBarButtonItem *first = [[UIBarButtonItem alloc] initWithTitle:@"<< First" style:UIBarButtonItemStyleBordered target:self action:@selector(hitFirst)];
    if (self.pages.currentPage > 1)
        first.enabled = NO;
    
    UIBarButtonItem *prev = [[UIBarButtonItem alloc] initWithTitle:@"< Prev" style:UIBarButtonItemStyleBordered target:self action:@selector(prevPage)];
    if (self.pages.currentPage > 1)
        prev.enabled = NO;
    
    
    NSString *pagesTitle = @"Loading...";
    if (self.pages.description)
        pagesTitle = self.pages.description;
    
    UIBarButtonItem *pages = [[UIBarButtonItem alloc] initWithTitle:pagesTitle style:UIBarButtonItemStyleBordered target:self action:@selector(pageSelection)];
    [pagesTitle release];
    
    self.pageButton = pages;
    
    UIBarButtonItem *next = [[UIBarButtonItem alloc] initWithTitle:@"Next >" style:UIBarButtonItemStyleBordered target:self action:@selector(nextPage)];
    if([self.pages onLastPage])
        next.enabled = NO;
    
    UIBarButtonItem *last = [[UIBarButtonItem alloc] initWithTitle:@"Last >>" style:UIBarButtonItemStyleBordered target:self action:@selector(hitLast)];
    if([self.pages onLastPage])
        last.enabled = NO;
    
    [items addObject:refresh];
    [items addObject:space];
    [items addObject:first];
    [items addObject:prev];
    [items addObject:pages];
    [items addObject:next];
    [items addObject:last];
    
    [self setToolbarItems:items];
    
    [refresh release];
    [space release];
    [first release];
    [prev release];
    [pages release];
    [next release];
    [last release];
    
    [self.navigationController setToolbarHidden:NO animated:YES];
}

-(void)hitActions
{
    AwfulNavigator *nav = getNavigator();
    [nav tappedAction];
}

#pragma mark -
#pragma mark UIPickerViewDataSource
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)thePickerView {
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)thePickerView numberOfRowsInComponent:(NSInteger)component {
    
    return self.pages.totalPages;
}

- (NSString *)pickerView:(UIPickerView *)thePickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    int page = row;
    page++;
    return [NSString stringWithFormat:@"%d", page];
}

- (void) gotoPageClicked
{
    int pageSelected = [self.pagePicker selectedRowInComponent:0] + 1;
    AwfulPageIpad *page = [[AwfulPageIpad alloc] initWithAwfulThread:self.thread startAt:AwfulPageDestinationTypeSpecific pageNum:pageSelected];
    loadContentVC(page);
    [page release];
    [self.popController dismissPopoverAnimated:YES];
}

#pragma mark -
#pragma mark Page Navigation

-(void)hitMore
{
    AwfulExtrasController *extras = [[AwfulExtrasController alloc] init];
    AwfulAppDelegate *del = (AwfulAppDelegate *)[[UIApplication sharedApplication] delegate];
    [del.splitController.pageController pushViewController:extras animated:YES];
    [extras release];
}

-(void)hitFirst
{
    AwfulPageIpad *first_page = [[AwfulPageIpad alloc] initWithAwfulThread:self.thread startAt:AwfulPageDestinationTypeFirst];
    loadContentVC(first_page);
    [first_page release];
}

-(void)nextPage
{
    if(![self.pages onLastPage]) {
        AwfulPageIpad *next_page = [[AwfulPageIpad alloc] initWithAwfulThread:self.thread startAt:AwfulPageDestinationTypeSpecific pageNum:self.pages.currentPage+1];
        loadContentVC(next_page);
        [next_page release];
    }
}

-(void)prevPage
{
    if(self.pages.currentPage > 1) {
        AwfulPageIpad *prev_page = [[AwfulPageIpad alloc] initWithAwfulThread:self.thread startAt:AwfulPageDestinationTypeSpecific pageNum:self.pages.currentPage-1];
        loadContentVC(prev_page);
        [prev_page release];
    }
}
-(void)hitLast
{
    if(![self.pages onLastPage]) {
        AwfulPageIpad *last_page = [[AwfulPageIpad alloc] initWithAwfulThread:self.thread startAt:AwfulPageDestinationTypeLast];
        loadContentVC(last_page);
        [last_page release];
    }
}

- (void)pageSelection
{   
    if(self.popController)
    {
        [self.popController dismissPopoverAnimated:YES];
        self.popController = nil;
    }
    
    self.pagePicker = [[UIPickerView alloc] initWithFrame:CGRectMake(0, 0, 320, 216)];
    self.pagePicker.dataSource = self;
    self.pagePicker.delegate = self;
    [self.pagePicker selectRow:[_pages currentPage]-1
                   inComponent:0
                      animated:NO];
    
    self.pagePicker.showsSelectionIndicator = YES;
    
    UIButton *goButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [goButton addTarget:self action:@selector(gotoPageClicked) forControlEvents:UIControlEventTouchUpInside];
    goButton.frame = CGRectMake(0, self.pagePicker.frame.size.height, 320, 40);
    
    [goButton setTitle:@"Goto Page" forState:UIControlStateNormal];
    
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, self.pagePicker.frame.size.height + 40)];
    
    [view addSubview:self.pagePicker]; 
    
    [view addSubview:goButton];
    
    
    UIViewController *vc = [[UIViewController alloc] init];
    vc.view = view;
    [view release];
    self.popController = [[UIPopoverController alloc] initWithContentViewController:vc];
    
    [self.popController setPopoverContentSize:view.frame.size animated:YES];
    [self.popController presentPopoverFromBarButtonItem:self.pageButton 
                               permittedArrowDirections:UIPopoverArrowDirectionAny
                                               animated:YES];
    
    
}

-(IBAction)hitForum : (id)sender
{
    if(self.thread.forum != nil) {
        AwfulThreadListIpad *list = [[AwfulThreadListIpad alloc] initWithAwfulForum:self.thread.forum];
        loadContentVC(list);
        [list release];
    }
}

#pragma mark -
#pragma mark Handle Updates

-(void)setPages:(AwfulPageCount *)pages
{
    [super setPages:pages];
    [self.pageButton setTitle:pages.description];
}

-(void)setThreadTitle : (NSString *)in_title
{
    [super setThreadTitle:in_title];
    UIButton *titleButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [titleButton setTitle:in_title forState:UIControlStateNormal];
    [titleButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [titleButton setTitleColor:[UIColor blackColor] forState:UIControlStateHighlighted];
    [titleButton setTitleColor:[UIColor blackColor] forState:UIControlStateSelected];
    [titleButton setTitleColor:[UIColor blackColor] forState:UIControlStateDisabled];

    [titleButton addTarget:self action:@selector(hitForum:) forControlEvents:UIControlEventTouchUpInside];

    titleButton.frame = CGRectMake(0, 0, getWidth()-50, 44);
    
    self.navigationItem.titleView = titleButton;
    
}

@end
