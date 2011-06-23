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

#define TITLE_BAR 0
#define READ_POSTS_BAR 1
#define AD_BAR 2
#define PAGES_LEFT_BAR 3
#define ITS_A_POST_YOU_IDIOT 4

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

float getMinHeight()
{
    UIInterfaceOrientation orient = [[UIApplication sharedApplication] statusBarOrientation];
    int height;
    if(UIInterfaceOrientationIsPortrait(orient)) {
        height = MIN_PORTRAIT_HEIGHT;
    } else {
        height = MIN_LANDSCAPE_HEIGHT;
    }
    return height;
}

#define WEB 5

@implementation AwfulPage

@synthesize thread = _thread;
@synthesize url = _url;
@synthesize pageHistory = _pageHistory;
@synthesize ad = _ad;
@synthesize adHTML = _adHTML;
@synthesize isBookmarked = _isBookmarked;
@synthesize highlightedPost = _highlightedPost;
@synthesize allRawPosts = _allRawPosts;
@synthesize renderedPosts = _renderedPosts;
@synthesize readPosts = _readPosts;
@synthesize unreadPosts = _unreadPosts;

@synthesize totalLoading = _totalLoading;
@synthesize totalFinished = _totalFinished;
@synthesize newPostIndex = _newPostIndex;

#pragma mark -
#pragma mark Initialization

/*
- (id)initWithStyle:(UITableViewStyle)style {
    // Override initWithStyle: if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
    if ((self = [super initWithStyle:style])) {
    }
    return self;
}
*/

-(id)initWithAwfulThread : (AwfulThread *)in_thread startAt : (AwfulPageDestinationType)thread_pos
{
    return [self initWithAwfulThread:in_thread startAt:thread_pos pageNum:-1];
}

-(id)initWithAwfulThread : (AwfulThread *)in_thread startAt : (AwfulPageDestinationType)thread_pos pageNum : (int)page_num
{
    if((self = [super initWithStyle:UITableViewStylePlain])) {
        _thread = [in_thread retain];
        
        _allRawPosts = [[NSMutableArray alloc] init];
        _renderedPosts = [[NSMutableArray alloc] init];
        _readPosts = [[NSMutableArray alloc] init];
        _unreadPosts = [[NSMutableArray alloc] init];
        
        _highlightedPost = nil;
        _newPostIndex = -1;
        _adHTML = nil;
        _ad = nil;
        
        self.pageHistory = nil;
        
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
    [_ad release];
    [_adHTML release];
    [_highlightedPost release];
    
    [_allRawPosts release];
    [_renderedPosts release];
    [_readPosts release];
    [_unreadPosts release];
    
    [super dealloc];
}

-(NSString *)getURLSuffix
{
    if(self.pages == nil) {
        return self.url;
    }
    return [NSString stringWithFormat:@"showthread.php?threadid=%@&pagenumber=%d", self.thread.threadID, self.pages.currentPage];
}

/*
-(void)setPages:(AwfulPageCount *)in_page
{
    if(in_page != pages) {
        [pages release];
        pages = [in_page retain];
        UILabel *page_label = (UILabel *)[titleBar viewWithTag:PAGE_TAG];
        page_label.text = [NSString stringWithFormat:@"pg %d of %d", pages.currentPage, pages.totalPages];
        [self.pageHistory setPageNum:pages.currentPage];
    }
}*/

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
    [super refresh];
    
    self.newPostIndex = -1;
    self.totalLoading = 0;
    self.totalFinished = 0;
    [self.allRawPosts removeAllObjects];
    [self.renderedPosts removeAllObjects];
    [self.unreadPosts removeAllObjects];
    [self.readPosts removeAllObjects];
    
    self.tableView.backgroundColor = [UIColor whiteColor];
    
    AwfulPageRefreshRequest *ref_req = [[AwfulPageRefreshRequest alloc] initWithAwfulPage:self];
    loadRequest(ref_req);
    [ref_req release];
}

-(void)refresh
{
    [super refresh];
    
    self.newPostIndex = -1;
    self.tableView.backgroundColor = [UIColor whiteColor];
    
    AwfulPageRefreshRequest *ref_req = [[AwfulPageRefreshRequest alloc] initWithAwfulPage:self];
    loadRequest(ref_req);
    [ref_req release];
}

-(void)stop
{
    [super stop];
    
    [self doneLoadingPage];
    for(UIWebView *web in self.renderedPosts) {
        [web stopLoading];
    }
}

-(void)acceptPosts : (NSMutableArray *)posts
{
    [self stopLoading];
    
    bottomAllowed = (self.pages.currentPage == self.pages.totalPages);
    
    int post_count_diff = [posts count] - [self.allRawPosts count];
    
    if(post_count_diff == 0) {
        [self doneLoadingPage];
        return;
    }
    
    [refreshHeaderView removeFromSuperview];
    
    // already displaying posts! just show new ones
    if([self.renderedPosts count] > 0) {
        [self.allRawPosts removeAllObjects];
        [self.allRawPosts addObjectsFromArray:posts];
        
        for(int i = [self.allRawPosts count] - post_count_diff; i < [self.allRawPosts count]; i++) {
            AwfulPost *post = [self.allRawPosts objectAtIndex:i];
            [self.unreadPosts addObject:post];
            UIWebView *web = [self newWebViewFromAwfulPost:post];
            [self.renderedPosts addObject:web];
            [web loadHTMLString:post.formattedHTML baseURL:[NSURL URLWithString:@""]];
            [web release];
        }
        return;
    }
    
    int start_index = 0;
    if(self.newPostIndex > 1) {
        start_index = self.newPostIndex-1;
    }
    
    int above_config = [AwfulConfig numReadPostsAbove];
    start_index = MAX(0, start_index - above_config);
    
    self.totalLoading = 0;
    self.totalFinished = 0;
    
    if(above_config < 10 && self.newPostIndex > 1) {
        if(start_index > 0) {
            self.newPostIndex = above_config+2;
        }
    }
    
    [self.allRawPosts removeAllObjects];
    [self.allRawPosts addObjectsFromArray:posts];
    
    for(int i = 0; i < start_index; i++) {
        if(i < [posts count]) {
            [self.readPosts addObject:[posts objectAtIndex:i]];
        }
    }
    
    for(int i = start_index; i < [posts count]; i++) {
        if(i < [posts count]) {
            [self.unreadPosts addObject:[posts objectAtIndex:i]];
        }
    }
    
    float offwhite = 241.0/255;
    self.tableView.backgroundColor = [UIColor colorWithRed:offwhite green:offwhite blue:offwhite alpha:1.0];
    
    for(AwfulPost *post in self.unreadPosts) {
        UIWebView *web = [self newWebViewFromAwfulPost:post];
        [self.renderedPosts addObject:web];
        [web loadHTMLString:post.formattedHTML baseURL:[NSURL URLWithString:@""]];
        [web release];
    }
}

-(void)acceptAd : (NSString *)ad_html
{
    self.adHTML = nil;
    self.adHTML = [[[NSString alloc] initWithString:ad_html] autorelease];
    
    int width = getWidth();
    int height = width * 0.128;
    
    UIWebView *web = [[UIWebView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
    [(UIScrollView *)[web.subviews objectAtIndex:0] setScrollEnabled:NO];
    [web loadHTMLString:self.adHTML baseURL:[NSURL URLWithString:@""]];
    self.ad = web;
    [web release];
    
    self.ad.delegate = self;
}

-(UIWebView *)newWebViewFromAwfulPost : (AwfulPost *)post
{
    UIWebView *web = [[UIWebView alloc] initWithFrame:CGRectMake(0, 0, getWidth(), 50)];
    [(UIScrollView *)[web.subviews objectAtIndex:0] setScrollEnabled:NO];
    web.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
    UIView *invis = [[UIView alloc] initWithFrame:CGRectMake(0, 0, getWidth(), 50)];
    invis.backgroundColor = [UIColor clearColor];
    UILongPressGestureRecognizer *hold = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(heldPost:)];
    [invis addGestureRecognizer:hold];
    invis.tag = TOUCH_POST;
    [hold release];
    
    web.tag = WEB;
    
    [web addSubview:invis];
    
    [invis release];
    
    web.delegate = self;
    
    UITapGestureRecognizer *image_gesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(imageGesture:)];
    image_gesture.delegate = self;
    [web addGestureRecognizer:image_gesture];
    [image_gesture release];
    
    return web;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tableView.separatorColor = [UIColor blackColor];
    [self.threadTitleLabel setText:self.thread.title];
    self.delegate.navigationItem.titleView = self.threadTitleLabel;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

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

-(void)scrollToRow : (int)row
{
    NSIndexPath *path = [NSIndexPath indexPathForRow:row inSection:0];
    @try {
        [self.tableView scrollToRowAtIndexPath:path atScrollPosition:UITableViewScrollPositionTop animated:YES];
    }
    @catch (NSException *exception) {
        NSLog(@"%@", [NSString stringWithFormat:@"failed to scroll to row %d", row]);
    }
}

-(void)doneLoadingPage
{
    [super stop];
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
        for(UIWebView *web in self.renderedPosts) {
            UIView *v = [web viewWithTag:TOUCH_POST];
            if(v == gestureRecognizer.view) {
                int index = [self.renderedPosts indexOfObject:web];
                if(index < [self.unreadPosts count]) {
                    self.highlightedPost = [self.unreadPosts objectAtIndex:index];
                }
            }
        }
        
        if(self.highlightedPost != nil) {
            //AwfulNavController *nav = getnav();
            //[nav showPostOptions:highlightedPost];
        }
    }
}

-(void)imageGesture : (UITapGestureRecognizer *)sender
{
    UIWebView *web = (UIWebView *)sender.view;
    
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
    }
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
    AwfulNavController *nav = getnav();
    
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

-(void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    /*[self stop];
    NSString *other_ad = [[NSString alloc] initWithString:adHTML];
    [self acceptAd:other_ad];
    [other_ad release];

    totalFinished = 0;
    totalLoading = 0;
    for(UIWebView *web in self.renderedPosts) {
        int index = [self.renderedPosts indexOfObject:web];
        if(index < [self.unreadPosts count]) {
            AwfulPost *post = [self.unreadPosts objectAtIndex:index];
            if(web != nil) {
                web.frame = CGRectMake(CGRectGetMinX(web.frame), CGRectGetMinY(web.frame), getWidth(), 100);
                [web loadHTMLString:post.formattedHTML baseURL:[NSURL URLWithString:@""]];
            }
        }
    }*/
    //[self.tableView reloadData];
}
/*
- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    UITableViewCell *winning_cell = nil;
    NSArray *visibles = [self.tableView visibleCells];
    if([visibles count] >= 2) {
        winning_cell = [visibles objectAtIndex:1];
    } else if([visibles count] == 1) {
        winning_cell = [visibles lastObject];
    }
    
    if(winning_cell != nil) {
        NSIndexPath *path = [self.tableView indexPathForCell:winning_cell];
        oldRotationRow = path.row;
    }
}*/

#pragma mark -
#pragma mark Table view data source

-(int)getTypeAtIndexPath : (NSIndexPath *)path
{    
    if([self.renderedPosts count] > 0) {
        
        int read_posts_extra = 0;
        if([self.readPosts count] > 0) {
            read_posts_extra = 1;
        }
        
        if(path.row == 0 && [self.readPosts count] > 0) {
            return READ_POSTS_BAR;
        }
        
        if(path.row == [self.renderedPosts count] + read_posts_extra) {
            if(self.ad != nil) {
                return AD_BAR;
            } else {
                return PAGES_LEFT_BAR;
            }
        }
        
        if(path.row == [self.renderedPosts count] + read_posts_extra + 1) {
            return PAGES_LEFT_BAR;
        }
        
        if(path.row < [self.renderedPosts count] + read_posts_extra) {
            return ITS_A_POST_YOU_IDIOT;
        }
    } else if(path.row == 1 && self.ad != nil) {
        return AD_BAR;
    }
    
    return PAGES_LEFT_BAR;
}

-(UIWebView *)getRenderedPostAtIndexPath : (NSIndexPath *)path
{
    int above_extra = 0;
    if([self.readPosts count] > 0) {
        above_extra++;
    }
    
    int index = path.row - above_extra;
    if(index < [self.renderedPosts count]) {
        return [self.renderedPosts objectAtIndex:index];
    }
    
    int type = [self getTypeAtIndexPath:path];
    if(type == AD_BAR) {
        return self.ad;
    }
    return nil;
}

-(NSUInteger)getRowForWebView : (UIWebView *)web
{
    int above_extra = 0;
    if([self.readPosts count] > 0) {
        above_extra++;
    }
    
    NSUInteger row = [self.renderedPosts indexOfObject:web];
    if(row != NSNotFound) {
        row += above_extra;
    }
    return row;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    
    int rows = 0;
    if(self.ad != nil) {
        // ad at bottom
        rows = 1;
    }
    
    if([self.renderedPosts count] > 0) {
        // X pages left at bottom
        if(self.pages.currentPage < self.pages.totalPages) {
            rows++;
        }
        
        // display too short, pull to refresh gets broken
        if(self.pages.currentPage == self.pages.totalPages && self.totalFinished > 0) {
            CGSize size = [self.tableView contentSize];
            if(size.height < self.tableView.frame.size.height) {
                //rows++;
            }
        }
        
        // x read posts above cell
        if([self.readPosts count] > 0) {
            rows++;
        }
        
        rows += [self.unreadPosts count];
    }
    
    return rows;
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    int type = [self getTypeAtIndexPath:indexPath];
    
    float height = 5;
    UIWebView *web;
    
    switch (type) {
        case READ_POSTS_BAR:
        case PAGES_LEFT_BAR:
            height = 60;
            break;
        case ITS_A_POST_YOU_IDIOT:
            web = [self getRenderedPostAtIndexPath:indexPath];
            height = CGRectGetHeight(web.frame);
            break;
        case AD_BAR:
            height = CGRectGetHeight(self.ad.frame);
            break;
        default:
            break;
    }
    
    // single post on page weirdness with pull to refresh
    if(self.pages.currentPage == self.pages.totalPages && type == ITS_A_POST_YOU_IDIOT && web == [self.renderedPosts lastObject]) {        
        float web_height = 45;
        for(UIWebView *web in self.renderedPosts) {
            web_height += web.frame.size.height;
        }
        
        if(self.ad != nil) {
            web_height += self.ad.frame.size.height;
        }
        
        if([self.readPosts count] > 0) {
            web_height += 60;
        }
        
        if(web_height < self.tableView.frame.size.height) {
            height += self.tableView.frame.size.height - web_height;
        }
    }
    
    return height;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *web_cell_ident = @"WebCell";
    static NSString *page_info_ident = @"PagesInfo";
    static NSString *read_posts_ident = @"ReadPosts";
    NSString *cell_ident = nil;
    
    int row_type = [self getTypeAtIndexPath:indexPath];
    
    if(row_type == ITS_A_POST_YOU_IDIOT || row_type == AD_BAR) {
        cell_ident = web_cell_ident;
    } else if(row_type == PAGES_LEFT_BAR) {
        cell_ident = page_info_ident;
    } else if(row_type == READ_POSTS_BAR) {
        cell_ident = read_posts_ident;
    }
    
    float offwhite = 241.0/255;
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cell_ident];
    
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cell_ident] autorelease];
        cell.contentView.backgroundColor = [UIColor colorWithRed:offwhite green:offwhite blue:offwhite alpha:1.0];
        if([cell_ident isEqualToString:web_cell_ident]) {
            UIWebView *web = [self getRenderedPostAtIndexPath:indexPath];
            if(web != nil) {
                [cell.contentView addSubview:web];
            }
        } else if([cell_ident isEqualToString:page_info_ident] || [cell_ident isEqualToString:read_posts_ident]) {
            cell.textLabel.textAlignment = UITextAlignmentCenter;
            cell.textLabel.backgroundColor = [UIColor colorWithRed:offwhite green:offwhite blue:offwhite alpha:1.0];
        }
    }
    
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    // Configure the cell...
    if([cell_ident isEqualToString:web_cell_ident]) {
        for(UIView *v in cell.contentView.subviews) {
            if([v isMemberOfClass:[UIWebView class]]) {
                [v removeFromSuperview];
            }
        }
        
        UIWebView *current_web = [self getRenderedPostAtIndexPath:indexPath];
        
        if(current_web != nil) {
            [cell.contentView addSubview:current_web];
        }
        
    } else if([cell_ident isEqualToString:page_info_ident]) {
        if(self.pages.currentPage == self.pages.totalPages) {
            cell.textLabel.text = @"";
        } else if(self.pages.currentPage == self.pages.totalPages - 1) {
            cell.textLabel.text = @"1 page left.";
         } else {
            cell.textLabel.text = [NSString stringWithFormat:@"%d pages left.", self.pages.totalPages-self.pages.currentPage];
        }
    } else if([cell_ident isEqualToString:read_posts_ident]) {
        if([self.readPosts count] == 1) {
            cell.textLabel.text = [NSString stringWithFormat:@"Load 1 earlier post"];
        } else {
            cell.textLabel.text = [NSString stringWithFormat:@"Load %d earlier posts", [self.readPosts count]];
        }
    }

    return cell;
}

-(void)webViewDidStartLoad:(UIWebView *)webView
{
    if(webView == self.ad) {
        return;
    }
    
    self.totalLoading++;
    if(self.totalLoading == [self.unreadPosts count]) {
        [self.tableView reloadData];
    }
}

-(BOOL)rowCheck : (int)row
{
    return row < [self.tableView numberOfRowsInSection:0];
}

-(void)webViewDidFinishLoad:(UIWebView *)sender
{
    if(sender == self.ad) {
        return;
    }
    
    //float height = [[sender stringByEvaluatingJavaScriptFromString:@"document.body.offsetHeight"] floatValue];
    //sender.frame = CGRectMake(0, 0, getWidth(), MAX(getMinHeight(), height));
    [sender sizeToFit];
    
    NSUInteger index = [self getRowForWebView:sender];
    if(index != NSNotFound) {
        NSIndexPath *path = [NSIndexPath indexPathForRow:index inSection:0];
        NSArray *paths = [[NSArray alloc] initWithObjects:path, nil];
        @try {
            [self.tableView reloadRowsAtIndexPaths:paths withRowAnimation:UITableViewRowAnimationNone];
        }
        @catch (NSException *exception) {
        }
    
        [paths release];
    }
    
    self.totalFinished++;
    if(self.totalFinished == [self.unreadPosts count]) {
        [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(finalRefresh) userInfo:nil repeats:NO];
        [self doneLoadingPage];
    }
}

-(void)reverifyHeights
{
    for(UIWebView *web in self.renderedPosts) {
        float height = [[web stringByEvaluatingJavaScriptFromString:@"document.body.offsetHeight"] floatValue];
        web.frame = CGRectMake(0, 0, getWidth(), MAX(getMinHeight(), height));
    }
    [self.tableView reloadData];
}

-(void)finalRefresh
{
    [self reverifyHeights];
    
    int winning_row = -1;
    /*if(oldRotationRow != -1) {
        winning_row = oldRotationRow;
    } else*/ if(self.newPostIndex > 1) {
        winning_row = self.newPostIndex;
    }
    
    if(winning_row != -1) {
        [self scrollToRow:winning_row];
    }
    //[Appirater userDidSignificantEvent:YES];
    
    if(bottomAllowed) {
        refreshHeaderView.center = CGPointMake(getWidth()/2, self.tableView.contentSize.height + refreshHeaderView.frame.size.height/2);
        [self.tableView addSubview:refreshHeaderView];
    }
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    NSLog(@"failed: %@", error);
}

// Override to support conditional editing of the table view.
/*- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

// Override to support editing the table view.
/*
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:YES];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}*/


/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/


/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

-(void)slideDown
{
}

-(void)slideUp
{
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

    int row_type = [self getTypeAtIndexPath:indexPath];
    if(row_type == PAGES_LEFT_BAR) {
        [self nextPage];
    } else if(row_type == READ_POSTS_BAR) {
        
        self.totalLoading = 0;
        self.totalFinished = 0;
        self.newPostIndex = 0;
        
        [self.renderedPosts removeAllObjects];
        
        for(AwfulPost *post in self.allRawPosts) {
            UIWebView *web = [self newWebViewFromAwfulPost:post];
            [self.renderedPosts addObject:web];
            [web release];
        }
        
        [self.readPosts removeAllObjects];
        [self.unreadPosts removeAllObjects];
        
        [self.unreadPosts addObjectsFromArray:self.allRawPosts];
                
        for(int i = 0; i < [self.allRawPosts count]; i++) {
            AwfulPost *post = [self.allRawPosts objectAtIndex:i];
            if(i < [self.renderedPosts count]) {
                UIWebView *web = [self.renderedPosts objectAtIndex:i];
                [web loadHTMLString:post.formattedHTML baseURL:[NSURL URLWithString:@""]];
            }
        }
    }
}


#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Relinquish ownership any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    // Relinquish ownership of anything that can be recreated in viewDidLoad or on demand.
    // For example: self.myOutlet = nil;
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

@end

