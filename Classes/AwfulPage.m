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
@synthesize pageHistory = _pageHistory;
@synthesize isBookmarked = _isBookmarked;
@synthesize highlightedPost = _highlightedPost;
@synthesize allRawPosts = _allRawPosts;
@synthesize newPostIndex = _newPostIndex;
@synthesize webView = _webView;
@synthesize pagesLabel = _pagesLabel;
@synthesize threadTitleLabel = _threadTitleLabel;
@synthesize pages = _pages;
@synthesize delegate = _delegate;

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
        
        _allRawPosts = [[NSMutableArray alloc] init];
        
        _highlightedPost = nil;
        _newPostIndex = -1;
        
        _pageHistory = nil;
        _webView = nil;
        
        NSString *append;
        switch(thread_pos) {
            case AwfulPageDestinationTypeFirst:
                append = @"";
                break;
            case AwfulPageDestinationTypeLast:
                append = @"&goto=lastpost";
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
    [_pageHistory release];
    [_highlightedPost release];
    
    [_allRawPosts release];
    [_webView release];
    [_pagesLabel release];
    [_threadTitleLabel release];
    [_pages release];
    
    [super dealloc];
}

-(void)setWebView:(UIWebView *)webView
{
    if(webView != _webView) {
        [_webView release];
        _webView = [webView retain];
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
        [self.pageHistory setPageNum:pages.currentPage];
    }
}

-(void)addBookmark
{
    ASIFormDataRequest *req = [ASIFormDataRequest requestWithURL:[NSURL URLWithString:@"http://forums.somethingawful.com/bookmarkthreads.php"]];
    req.userInfo = [NSDictionary dictionaryWithObject:@"Added to bookmarks." forKey:@"completionMsg"];
    
    [req setPostValue:@"1" forKey:@"json"];
    [req setPostValue:@"add" forKey:@"action"];
    [req setPostValue:self.thread.threadID forKey:@"threadid"];
    self.isBookmarked = YES;
    
    NSMutableArray *bookmarked_threads = [AwfulUtil newThreadListForForumId:@"bookmarks"];
    [bookmarked_threads addObject:self.thread];
    [AwfulUtil saveThreadList:bookmarked_threads forForumId:@"bookmarks"];
    [bookmarked_threads release];
    
    loadRequestAndWait(req);
}

-(void)removeBookmark
{
    ASIFormDataRequest *req = [ASIFormDataRequest requestWithURL:[NSURL URLWithString:@"http://forums.somethingawful.com/bookmarkthreads.php"]];
    req.userInfo = [NSDictionary dictionaryWithObject:@"Removed from bookmarks." forKey:@"completionMsg"];
    
    [req setPostValue:@"1" forKey:@"json"];
    [req setPostValue:@"remove" forKey:@"action"];
    [req setPostValue:self.thread.threadID forKey:@"threadid"];
    self.isBookmarked = NO;
    
    NSMutableArray *bookmarked_threads = [AwfulUtil newThreadListForForumId:@"bookmarks"];
    AwfulThread *found = nil;
    for(AwfulThread *thread in bookmarked_threads) {
        if([thread.threadID isEqualToString:self.thread.threadID]) {
            found = thread;
        }
    }
    [bookmarked_threads removeObject:found];
    [AwfulUtil saveThreadList:bookmarked_threads forForumId:@"bookmarks"];
    [bookmarked_threads release];
    
    loadRequestAndWait(req);
}

-(void)setThreadTitle : (NSString *)in_title
{
    [self.thread setTitle:in_title];
    [self.threadTitleLabel setText:in_title];
}

-(void)hardRefresh
{
    [self.delegate swapToStopButton];
    
    self.newPostIndex = -1;
    [self.allRawPosts removeAllObjects];
    
    AwfulPageRefreshRequest *ref_req = [[AwfulPageRefreshRequest alloc] initWithAwfulPage:self];
    loadRequest(ref_req);
    [ref_req release];
}

-(void)refresh
{    
    self.newPostIndex = -1;
    
    AwfulPageRefreshRequest *ref_req = [[AwfulPageRefreshRequest alloc] initWithAwfulPage:self];
    loadRequest(ref_req);
    [ref_req release];
}

-(void)stop
{
}

-(void)acceptPosts : (NSMutableArray *)posts
{    
    [self.delegate swapToRefreshButton];
    self.allRawPosts = posts;
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
    
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    NSLog(@"failed: %@", error);
}

-(void)nextPage
{
    if(self.pages.currentPage < self.pages.totalPages) {
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
    if(self.highlightedPost == nil) {
        /*for(UIWebView *web in self.renderedPosts) {
            UIView *v = [web viewWithTag:TOUCH_POST];
            if(v == gestureRecognizer.view) {
                int index = [self.renderedPosts indexOfObject:web];
                if(index < [self.unreadPosts count]) {
                    self.highlightedPost = [self.unreadPosts objectAtIndex:index];
                }
            }
        }*/
        
        if(self.highlightedPost != nil) {
            //AwfulNavController *nav = getnav();
            //[nav showPostOptions:highlightedPost];
        }
    }
}

-(void)imageGesture : (UITapGestureRecognizer *)sender
{
    /*UIWebView *web = (UIWebView *)sender.view;
    
    NSUInteger post_index = [self.renderedPosts indexOfObject:web];
    
    CGPoint p = [sender locationInView:web];
    NSString *js_tag_name = [NSString stringWithFormat:@"document.elementFromPoint(%f, %f).tagName", p.x, p.y];
    NSString *tag_name = [web stringByEvaluatingJavaScriptFromString:js_tag_name];
    if([tag_name isEqualToString:@"IMG"]) {
        NSString *js_src = [NSString stringWithFormat:@"document.elementFromPoint(%f, %f).src", p.x, p.y];
        NSString *src = [web stringByEvaluatingJavaScriptFromString:js_src];
        
        BOOL proceed = YES;
        if(post_index != NSNotFound && post_index < [self.unreadPosts count]) {
            if(post_index < [self.unreadPosts count])  {
                AwfulPost *post = [self.unreadPosts objectAtIndex:post_index];
                if([[post.avatarURL absoluteString] isEqualToString:src]) {
                    proceed = NO;
                }
            }
        }
        
        if(proceed) {
            //AwfulNavController *nav = getnav();
            //[nav showImage:src];
        }
    }*/
}

-(void)chosePostOption : (int)option
{    
    int actual_option = option;
    if(!self.highlightedPost.canEdit) {
        actual_option++;
    }
    
    if(actual_option == 0) {
        if(self.highlightedPost.canEdit) {
            AwfulEditContentRequest *edit_req = [[AwfulEditContentRequest alloc] initWithAwfulPage:self forAwfulPost:self.highlightedPost];
            loadRequest(edit_req);
            [edit_req release];
        }
    } else if(actual_option == 1) {
        
        AwfulQuoteRequest *quote_req = [[AwfulQuoteRequest alloc] initWithPost:self.highlightedPost fromPage:self];
        loadRequest(quote_req);
        [quote_req release];
        
    } else if(actual_option == 2) {
        NSString *html = [[NSString alloc] initWithFormat:@"<html><head><link rel='stylesheet' type='text/css' href='/css/main.css'><link rel='stylesheet' type='text/css' href='/css/bbcode.css'></head><body>%@</body></html>", self.highlightedPost.rawContent];
        [(AwfulNavController *)self.navigationController showUnfilteredWithHTML:html];
        [html release];
        
    } else if(actual_option == 3) {
        if(self.highlightedPost.markSeenLink != nil) {
            NSURL *seen_url = [NSURL URLWithString:[@"http://forums.somethingawful.com/" stringByAppendingString:self.highlightedPost.markSeenLink]];
            ASIHTTPRequest *seen_req = [ASIHTTPRequest requestWithURL:seen_url];
            seen_req.userInfo = [NSDictionary dictionaryWithObjectsAndKeys:@"Marked up to there.", @"completionMsg", nil];
            loadRequestAndWait(seen_req);
        } else {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Not available" message:@"That feature requires you set 'Show an icon next to each post indicating if it has been seen or not' in your forum options" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
            [alert show];
            [alert release];
        }
    }   
    self.highlightedPost = nil;
}

-(void)choseThreadOption : (int)option
{    
    /*AwfulNavController *nav = getnav();
    
    if(option == 0) {
        [nav showPageNumberNav:self];
    } else if(option == 1) {
        [nav showVoteOptions:self];
    } else if(option == 2) {
        AwfulPostBoxController *post_box = [[AwfulPostBoxController alloc] initWithText:@""];
        [post_box setReplyBox:self.thread];
        AwfulNavController *nav = getnav();
        [nav presentModalViewController:post_box animated:YES];
        [post_box release];
    } else if(option == 3) {
        if(self.isBookmarked) {
            [self removeBookmark];
        } else {
            [self addBookmark];
        }
    } else if(option == 4) {
        [self nextPage];
    }*/
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
    
    self.pagesLabel.text = [self.pages description];
    self.threadTitleLabel.text = self.thread.title;
    self.delegate.navigationItem.titleView = self.threadTitleLabel;
    
    UIBarButtonItem *cust = [[UIBarButtonItem alloc] initWithCustomView:self.pagesLabel];
    self.navigationItem.rightBarButtonItem = cust;
    [cust release];
}

- (void)viewDidUnload {
    // Relinquish ownership of anything that can be recreated in viewDidLoad or on demand.
    // For example: self.myOutlet = nil;
    self.pagesLabel = nil;
    self.threadTitleLabel = nil;
}

#pragma mark -
#pragma mark AwfulHistoryRecorder

-(id)newRecordedHistory
{
    AwfulHistory *hist = [[AwfulHistory alloc] init];
    hist.pageNum = self.pages.currentPage;
    hist.modelObj = self.thread;
    hist.historyType = AWFUL_HISTORY_PAGE;
    [self setRecorder:hist];
    return hist;
}

-(id)initWithAwfulHistory : (AwfulHistory *)history
{
    return [self initWithAwfulThread:history.modelObj startAt:AwfulPageDestinationTypeSpecific pageNum:history.pageNum];
}

-(void)setRecorder : (AwfulHistory *)history
{
    self.pageHistory = history;
}

#pragma mark -
#pragma mark Navigator Contnet

-(UIView *)getView
{
    return self.view;
}

@end

