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
#import "AwfulPageNavController.h"
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
#import "MWPhoto.h"
#import "MWPhotoBrowser.h"

float getWidth()
{
    UIInterfaceOrientation orient = [[UIApplication sharedApplication] statusBarOrientation];
    float post_width;
    if(UIInterfaceOrientationIsPortrait(orient)) {
        post_width = 320;
    } else {
        post_width = 480;
    }
    return post_width;
}

@implementation AwfulPage

@synthesize thread = _thread;
@synthesize url = _url;
@synthesize isBookmarked = _isBookmarked;
@synthesize allRawPosts = _allRawPosts;
@synthesize webView = _webView;
@synthesize pagesLabel = _pagesLabel;
@synthesize threadTitleLabel = _threadTitleLabel;
@synthesize pages = _pages;
@synthesize delegate = _delegate;
@synthesize forumButton = _forumButton;
@synthesize shouldScrollToBottom = _shouldScrollToBottom;
@synthesize scrollToPostID = _scrollToPostID;

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
        
        _allRawPosts = [[NSMutableArray alloc] init];

        _webView = nil;
        
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
    [_webView release];
    [_pagesLabel release];
    [_threadTitleLabel release];
    [_forumButton release];
    [_pages release];
    [_scrollToPostID release];
    
    [super dealloc];
}

-(void)setWebView:(JSBridgeWebView *)webView;
{
    if(webView != _webView) {
        [_webView release];
        _webView = [webView retain];
        
        UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(heldPost:)];
        press.delegate = self;
        press.minimumPressDuration = 0.3;
        [_webView addGestureRecognizer:press];
        [press release];
        
        AwfulNavigator *nav = getNavigator();
        UITapGestureRecognizer *three_times = [[UITapGestureRecognizer alloc] initWithTarget:nav action:@selector(tappedThreeTimes:)];
        three_times.numberOfTapsRequired = 3;
        three_times.delegate = self;
        [_webView addGestureRecognizer:three_times];
        [three_times release];
        
        _webView.delegate = self;
        self.view = _webView;
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
-(void)tappedTitle : (UITapGestureRecognizer *)tapper
{
    float x = self.view.frame.size.width/2;
    
    if(self.forumButton == nil) {
        [[NSBundle mainBundle] loadNibNamed:@"AwfulForumButton" owner:self options:nil];
        [self.forumButton setTitle:self.thread.forum.name forState:UIControlStateNormal];
        self.forumButton.center = CGPointMake(x, -self.forumButton.frame.size.height/2);
        [self.webView addSubview:self.forumButton];
        [UIView animateWithDuration:0.5 animations:^(){
            self.forumButton.center = CGPointMake(x, self.forumButton.frame.size.height/2);
        }];
    } else {
        [UIView animateWithDuration:0.5 animations:^(){
            self.forumButton.center = CGPointMake(x, -self.forumButton.frame.size.height/2);
        } completion:^(BOOL finished){
            [self.forumButton removeFromSuperview];
            self.forumButton = nil;
        }];
    }
}

-(IBAction)tappedForumButton
{
    if(self.thread.forum != nil) {
        AwfulThreadList *list = [[AwfulThreadList alloc] initWithAwfulForum:self.thread.forum];
        loadContentVC(list);
        [list release];
    }
}

-(void)hardRefresh
{    
    AwfulPageDestinationType dest = AwfulPageDestinationTypeNewpost;
    
    if([self.pages onLastPage]) {
        dest = AwfulPageDestinationTypeLast;
    }
    
    AwfulPage *fresh_page = [[AwfulPage alloc] initWithAwfulThread:self.thread startAt:dest];
    loadContentVC(fresh_page);
    [fresh_page release];
}

-(void)refresh
{    
    AwfulPageRefreshRequest *ref_req = [[AwfulPageRefreshRequest alloc] initWithAwfulPage:self];
    loadRequestAndWait(ref_req);
    [ref_req release];
}

-(void)stop
{
}

-(void)loadOlderPosts
{
    int pages_left = self.pages.totalPages - self.pages.currentPage;
    NSString *html = [AwfulParse constructPageHTMLFromPosts:self.allRawPosts pagesLeft:pages_left numOldPosts:0];
    
    AwfulNavigator *nav = getNavigator();
    JSBridgeWebView *web = [[JSBridgeWebView alloc] initWithFrame:nav.view.frame];
    [web loadHTMLString:html baseURL:[NSURL URLWithString:@""]];
    self.webView = web;
    [web release];
    nav.view = self.webView;
}

-(void)acceptPosts : (NSMutableArray *)posts
{    
    [self.delegate swapToRefreshButton];
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
    CGPoint p = [gestureRecognizer locationInView:self.webView];
    NSString *offset_str = [self.webView stringByEvaluatingJavaScriptFromString:@"scrollY"];
    float offset = [offset_str intValue];
    
    NSString *js_tag_name = [NSString stringWithFormat:@"document.elementFromPoint(%f, %f).tagName", p.x, p.y+offset];
    NSString *tag_name = [self.webView stringByEvaluatingJavaScriptFromString:js_tag_name];
    if([tag_name isEqualToString:@"IMG"]) {
        NSString *js_src = [NSString stringWithFormat:@"document.elementFromPoint(%f, %f).src", p.x, p.y+offset];
        NSString *src = [self.webView stringByEvaluatingJavaScriptFromString:js_src];
        
        BOOL proceed = YES;
        for(AwfulPost *post in self.allRawPosts) {
            if([[post.avatarURL absoluteString] isEqualToString:src]) {
                proceed = NO;
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
        [self.webView stringByEvaluatingJavaScriptFromString:scrolling];
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
    self.pagesLabel = labels.pagesLabel;
    self.threadTitleLabel = labels.threadTitleLabel;
    [labels release];
    
    UIView *label_container = [[UIView alloc] initWithFrame:self.threadTitleLabel.frame];
    [label_container setBackgroundColor:[UIColor clearColor]];
    [label_container addSubview:self.threadTitleLabel];
    self.threadTitleLabel.frame = CGRectMake(0, 0, self.threadTitleLabel.bounds.size.width, self.threadTitleLabel.bounds.size.height);
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedTitle:)];
    [label_container addGestureRecognizer:tap];
    [tap release];
    
    self.pagesLabel.text = [self.pages description];
    self.threadTitleLabel.text = self.thread.title;
    self.delegate.navigationItem.titleView = label_container;
    [label_container release];
    
    UIBarButtonItem *cust = [[UIBarButtonItem alloc] initWithCustomView:self.pagesLabel];
    self.delegate.navigationItem.rightBarButtonItem = cust;
    [cust release];
}

- (void)viewDidUnload {
    // Relinquish ownership of anything that can be recreated in viewDidLoad or on demand.
    // For example: self.myOutlet = nil;
    self.pagesLabel = nil;
    self.threadTitleLabel = nil;
    self.forumButton = nil;
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
    [self.webView stringByEvaluatingJavaScriptFromString:@"window.scrollTo(0, document.body.scrollHeight);"];
}

-(void)scrollToSpecifiedPost
{
    [self scrollToPost:self.scrollToPostID];
}

#pragma mark JSBBridgeWebDelegate

- (void)webView:(UIWebView*) webview didReceiveJSNotificationWithDictionary:(NSDictionary*) dictionary
{
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

#pragma mark Gesture Delegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

#pragma mark Web View Delegate

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{    
    
    if(navigationType == UIWebViewNavigationTypeLinkClicked) {
        
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
        }
        
        OtherWebController *other = [[OtherWebController alloc] initWithURL:request.URL];
        UINavigationController *other_nav = [[UINavigationController alloc] initWithRootViewController:other];
        other_nav.navigationBar.barStyle = UIBarStyleBlack;
        [other_nav setToolbarHidden:NO];
        other_nav.toolbar.barStyle = UIBarStyleBlack;
        [other release];
        
        AwfulNavigator *nav = getNavigator();
        [nav presentModalViewController:other_nav animated:YES];
        [other_nav release];
        
        return NO;
    }
    return YES;
}

-(void)webViewDidFinishLoad:(UIWebView *)sender
{
    if(self.scrollToPostID != nil) {
        [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(scrollToSpecifiedPost) userInfo:nil repeats:NO];
    } else if(self.shouldScrollToBottom) {
        [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(scrollToBottom) userInfo:nil repeats:NO];
    }
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    NSLog(@"failed: %@", error);
}

@end

