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
#import "AwfulConfig.h"

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

@synthesize pages, currentURL, thread, pageHistory;
@synthesize ad, isBookmarked, newPostIndex;
@synthesize adHTML;
@synthesize allRawPosts = _allRawPosts;
@synthesize renderedPosts = _renderedPosts;
@synthesize readPosts = _readPosts;
@synthesize unreadPosts = _unreadPosts;

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

-(id)initWithAwfulThread : (AwfulThread *)in_thread startAt : (int)thread_pos
{
    return [self initWithAwfulThread:in_thread startAt:thread_pos pageNum:-1];
}

-(id)initWithAwfulThread : (AwfulThread *)in_thread startAt : (int)thread_pos pageNum : (int)page_num
{
    if((self = [super initWithStyle:UITableViewStylePlain])) {
        thread = [in_thread retain];
        
        _allRawPosts = [[NSMutableArray alloc] init];
        _renderedPosts = [[NSMutableArray alloc] init];
        _readPosts = [[NSMutableArray alloc] init];
        _unreadPosts = [[NSMutableArray alloc] init];
        
        pages = nil;
        highlightedPost = nil;
        newPostIndex = -1;
        oldRotationRow = -1;
        adHTML = nil;
        ad = nil;
        self.pageHistory = nil;
        
        NSString *append;
        switch(thread_pos) {
            case THREAD_POS_FIRST:
                append = @"";
                break;
            case THREAD_POS_LAST:
                append = @"&goto=lastpost";
                break;
            case THREAD_POS_NEWPOST:
                append = @"&goto=newpost";
                break;
            case THREAD_POS_SPECIFIC:
                append = [NSString stringWithFormat:@"&pagenumber=%d", page_num];
                break;
            default:
                append = @"";
                break;
        }
        
        currentURL = [[NSString alloc] initWithFormat:@"showthread.php?threadid=%@%@", thread.threadID, append];
        
        UIFont *f = [UIFont fontWithName:@"Helvetica-Bold" size:11.0];
        
        UILabel *thread_title_label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 230, 45)];
        thread_title_label.font = f;
        thread_title_label.numberOfLines = 3;
        thread_title_label.text = thread.threadTitle;
        thread_title_label.textAlignment = UITextAlignmentCenter;
        thread_title_label.textColor = [UIColor whiteColor];
        thread_title_label.backgroundColor = [UIColor clearColor];
        thread_title_label.center = CGPointMake(160, 20);
        thread_title_label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        thread_title_label.tag = THREAD_TITLE_LABEL;
        
        UILabel *page_label = [[UILabel alloc] initWithFrame:CGRectMake(275, 0, 40, 45)];
        page_label.font = [UIFont fontWithName:@"Helvetica" size:10.0];
        page_label.numberOfLines = 2;
        page_label.textAlignment = UITextAlignmentCenter;
        page_label.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        page_label.textColor = [UIColor whiteColor];
        page_label.backgroundColor = [UIColor clearColor];
        page_label.tag = PAGE_TAG;
        
        isReplying = NO;
        
        [self makeButtons];
        
        titleBar = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 320, 45)];
        [titleBar setImage:[UIImage imageNamed:@"nav_bar_landscape_bg_iphone.png"]];
        [titleBar addSubview:thread_title_label];
        titleBar.userInteractionEnabled = YES;
        titleBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        
        
        [titleBar addSubview:refreshButton];
        [titleBar addSubview:page_label];
        [page_label release];
        [thread_title_label release];
        
        isBookmarked = NO;
        NSMutableArray *bookmarked_threads = [AwfulUtil newThreadListForForumId:@"bookmarks"];
        for(AwfulThread *t in bookmarked_threads) {
            if([t.threadID isEqualToString:thread.threadID]) {
                isBookmarked = YES;
            }
        }
        [bookmarked_threads release];
    }
    return self;
}

- (void)dealloc {
    [ad release];
    [currentURL release];
    [pages release];
    [thread release];
    [titleBar release];
    [refreshButton release];
    [stopButton release];
    [nextPageButton release];
    [prevPageButton release];
    [adHTML release];
    
    self.allRawPosts = nil;
    self.renderedPosts = nil;
    self.readPosts = nil;
    self.unreadPosts = nil;
    
    [super dealloc];
}

-(NSString *)getURLSuffix
{
    if(pages == nil) {
        return currentURL;
    }
    return [NSString stringWithFormat:@"showthread.php?threadid=%@&pagenumber=%d", thread.threadID, pages.current];
}

-(void)makeButtons
{
    refreshButton = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
    refreshButton.frame = CGRectMake(5, 0, 40, 40);
    [refreshButton setImage:[UIImage imageNamed:@"reload.png"] forState:UIControlStateNormal];
    [refreshButton addTarget:self action:@selector(hardRefresh) forControlEvents:UIControlEventTouchUpInside];
    
    stopButton = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
    stopButton.frame = CGRectMake(5, 0, 40, 40);
    [stopButton setImage:[UIImage imageNamed:@"stop.png"] forState:UIControlStateNormal];
    [stopButton addTarget:self action:@selector(stop) forControlEvents:UIControlEventTouchUpInside];
    
    nextPageButton = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
    nextPageButton.frame = CGRectMake(270, 10, 40, 40);
    nextPageButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [nextPageButton setImage:[UIImage imageNamed:@"arrowright.png"] forState:UIControlStateNormal];
    [nextPageButton addTarget:self action:@selector(nextPage) forControlEvents:UIControlEventTouchUpInside];
    
    prevPageButton = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
    prevPageButton.frame = CGRectMake(10, 10, 40, 40);
    prevPageButton.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
    [prevPageButton setImage:[UIImage imageNamed:@"arrowleft.png"] forState:UIControlStateNormal];
    [prevPageButton addTarget:self action:@selector(prevPage) forControlEvents:UIControlEventTouchUpInside];
}

-(void)setPages:(PageManager *)in_page
{
    if(in_page != pages) {
        [pages release];
        pages = [in_page retain];
        UILabel *page_label = (UILabel *)[titleBar viewWithTag:PAGE_TAG];
        page_label.text = [NSString stringWithFormat:@"pg %d of %d", pages.current, pages.total];
        [self.pageHistory setPageNum:pages.current];
    }
}

-(void)addBookmark
{
    ASIFormDataRequest *req = [ASIFormDataRequest requestWithURL:[NSURL URLWithString:@"http://forums.somethingawful.com/bookmarkthreads.php"]];
    req.userInfo = [NSDictionary dictionaryWithObject:@"Added to bookmarks." forKey:@"completionMsg"];
    
    [req setPostValue:@"1" forKey:@"json"];
    [req setPostValue:@"add" forKey:@"action"];
    [req setPostValue:thread.threadID forKey:@"threadid"];
    isBookmarked = YES;
    
    NSMutableArray *bookmarked_threads = [AwfulUtil newThreadListForForumId:@"bookmarks"];
    [bookmarked_threads addObject:thread];
    [AwfulUtil saveThreadList:bookmarked_threads forForumId:@"bookmarks"];
    [bookmarked_threads release];
    
    AwfulNavController *nav = getnav();
    [nav loadRequestAndWait:req];
}

-(void)removeBookmark
{
    ASIFormDataRequest *req = [ASIFormDataRequest requestWithURL:[NSURL URLWithString:@"http://forums.somethingawful.com/bookmarkthreads.php"]];
    req.userInfo = [NSDictionary dictionaryWithObject:@"Removed from bookmarks." forKey:@"completionMsg"];
    
    [req setPostValue:@"1" forKey:@"json"];
    [req setPostValue:@"remove" forKey:@"action"];
    [req setPostValue:thread.threadID forKey:@"threadid"];
    isBookmarked = NO;
    
    NSMutableArray *bookmarked_threads = [AwfulUtil newThreadListForForumId:@"bookmarks"];
    AwfulThread *found = nil;
    for(AwfulThread *t in bookmarked_threads) {
        if([t.threadID isEqualToString:thread.threadID]) {
            found = t;
        }
    }
    [bookmarked_threads removeObject:found];
    [AwfulUtil saveThreadList:bookmarked_threads forForumId:@"bookmarks"];
    [bookmarked_threads release];
    
    AwfulNavController *nav = getnav();
    [nav loadRequestAndWait:req];
}

-(void)setThreadTitle : (NSString *)in_title
{
    UILabel *lab = (UILabel *)[titleBar viewWithTag:THREAD_TITLE_LABEL];
    lab.text = in_title;
    [thread setThreadTitle:in_title];
}

-(void)swapToView : (UIView *)v
{
    if(v == stopButton) {
        [[refreshButton superview] addSubview:stopButton];
        [refreshButton removeFromSuperview];
    } else {
        [[stopButton superview] addSubview:refreshButton];
        [stopButton removeFromSuperview];
    }
}

-(void)refresh
{
    [self swapToView:stopButton];

    newPostIndex = -1;
    oldRotationRow = -1;
    self.tableView.backgroundColor = [UIColor whiteColor];
    
    AwfulNavController *nav = getnav();
    AwfulPageRefreshRequest *ref_req = [[AwfulPageRefreshRequest alloc] initWithAwfulPage:self];
    [nav loadRequest:ref_req];
    [ref_req release];
}

-(void)hardRefresh
{
    [self swapToView:stopButton];
    
    newPostIndex = -1;
    oldRotationRow = -1;
    totalLoading = 0;
    totalFinished = 0;
    [self.allRawPosts removeAllObjects];
    [self.renderedPosts removeAllObjects];
    [self.unreadPosts removeAllObjects];
    [self.readPosts removeAllObjects];
    self.tableView.backgroundColor = [UIColor whiteColor];
    
    AwfulNavController *nav = getnav();
    AwfulPageRefreshRequest *ref_req = [[AwfulPageRefreshRequest alloc] initWithAwfulPage:self];
    [nav loadRequest:ref_req];
    [ref_req release];
}

-(void)stop
{
    AwfulNavController *nav = getnav();
    [nav stopAllRequests];
    
    [self doneLoadingPage];
    for(UIWebView *web in self.renderedPosts) {
        [web stopLoading];
    }
}

-(void)acceptPosts : (NSMutableArray *)posts
{
    [self stopLoading];
    
    bottomAllowed = (pages.current == pages.total);
    
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
            [web loadHTMLString:post.content baseURL:[NSURL URLWithString:@""]];
            [web release];
        }
        return;
    }
    
    int start_index = 0;
    if(newPostIndex > 1) {
        start_index = newPostIndex-1;
    }
    
    int above_config = [AwfulConfig numReadPostsAbove];
    start_index = MAX(0, start_index - above_config);
    
    totalLoading = 0;
    totalFinished = 0;
    
    if(above_config < 10 && newPostIndex > 1) {
        if(start_index > 0) {
            newPostIndex = above_config+2;
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
        [web loadHTMLString:post.content baseURL:[NSURL URLWithString:@""]];
        [web release];
    }
}

-(void)acceptAd : (NSString *)ad_html
{
    [adHTML release];
    adHTML = [[NSString alloc] initWithString:ad_html];
    
    int width = getWidth();
    int height = width * 0.128;
    
    UIWebView *web = [[UIWebView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
    [(UIScrollView *)[web.subviews objectAtIndex:0] setScrollEnabled:NO];
    [web loadHTMLString:adHTML baseURL:[NSURL URLWithString:@""]];
    [self setAd:web];
    [web release];
    
    ad.delegate = self;
}

-(UIWebView *)newWebViewFromAwfulPost : (AwfulPost *)post
{
    UIWebView *web = [[UIWebView alloc] initWithFrame:CGRectMake(0, 0, getWidth(), 50)];
    [(UIScrollView *)[web.subviews objectAtIndex:0] setScrollEnabled:NO];
    
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
    
    self.tableView.separatorColor = [UIColor blackColor];//[UIColor colorWithRed:0.75 green:0.75 blue:0.75 alpha:1.0];

    AwfulAppDelegate *del = (AwfulAppDelegate *)[[UIApplication sharedApplication] delegate];
    AwfulNavController *nav = del.navController;
    
    NSArray *items = [nav getToolbarItems];
    [self setToolbarItems:items];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{    
    AwfulNavController *nav = getnav();

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
                    page = [[AwfulPage alloc] initWithAwfulThread:intra startAt:THREAD_POS_FIRST];
                } else {
                    page = [[AwfulPage alloc] initWithAwfulThread:intra startAt:THREAD_POS_SPECIFIC pageNum:[page_number intValue]];
                    int pti = [AwfulParse getNewPostNumFromURL:request.URL];
                    page.currentURL = [NSString stringWithFormat:@"showthread.php?threadid=%@&pagenumber=%@#pti%d", thread_id, page_number, pti];
                }
                
                [intra release];
                
                if(page != nil) {
                    AwfulNavController *nav = getnav();
                    [nav loadPage:page];
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
    [self swapToView:refreshButton];
}

-(void)nextPage
{
    if(pages.current < pages.total) {
        AwfulPage *next_page = [[AwfulPage alloc] initWithAwfulThread:thread startAt:THREAD_POS_SPECIFIC pageNum:pages.current+1];
        AwfulNavController *nav = getnav();
        [nav loadPage:next_page];
        [next_page release];
    }
}

-(void)prevPage
{
    if(pages.current > 1) {
        AwfulPage *prev_page = [[AwfulPage alloc] initWithAwfulThread:thread startAt:THREAD_POS_SPECIFIC pageNum:pages.current-1];
        AwfulNavController *nav = getnav();
        [nav loadPage:prev_page];
        [prev_page release];
    }
}

-(void)heldPost:(UILongPressGestureRecognizer *)gestureRecognizer
{
    if(highlightedPost == nil) {
        for(UIWebView *web in self.renderedPosts) {
            UIView *v = [web viewWithTag:TOUCH_POST];
            if(v == gestureRecognizer.view) {
                int index = [self.renderedPosts indexOfObject:web];
                if(index < [self.unreadPosts count]) {
                    highlightedPost = [self.unreadPosts objectAtIndex:index];
                }
            }
        }
        
        if(highlightedPost != nil) {
            AwfulNavController *nav = getnav();
            [nav showPostOptions:highlightedPost];
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
                if([post.avatar isEqualToString:src]) {
                    proceed = NO;
                }
            }
        }
        
        if(proceed) {
            AwfulNavController *nav = getnav();
            [nav showImage:src];
        }
    }
}

-(void)chosePostOption : (int)option
{
    AwfulNavController *nav = getnav();
    
    int actual_option = option;
    if(!highlightedPost.canEdit) {
        actual_option++;
    }
    
    if(actual_option == 0) {
        if(highlightedPost.canEdit) {
            AwfulEditContentRequest *edit_req = [[AwfulEditContentRequest alloc] initWithAwfulPage:self forAwfulPost:highlightedPost];
            [nav loadRequest:edit_req];
            [edit_req release];
        }
    } else if(actual_option == 1) {
        
        AwfulQuoteRequest *quote_req = [[AwfulQuoteRequest alloc] initWithPost:highlightedPost fromPage:self];
        [nav loadRequest:quote_req];
        [quote_req release];
        
    } else if(actual_option == 2) {
        NSString *html = [[NSString alloc] initWithFormat:@"<html><head><link rel='stylesheet' type='text/css' href='/css/main.css'><link rel='stylesheet' type='text/css' href='/css/bbcode.css'></head><body>%@</body></html>", highlightedPost.rawContent];
        [(AwfulNavController *)self.navigationController showUnfilteredWithHTML:html];
        [html release];
        
    } else if(actual_option == 3) {
        if(highlightedPost.seenLink != nil) {
            NSURL *seen_url = [NSURL URLWithString:[@"http://forums.somethingawful.com/" stringByAppendingString:highlightedPost.seenLink]];
            ASIHTTPRequest *seen_req = [ASIHTTPRequest requestWithURL:seen_url];
            seen_req.userInfo = [NSDictionary dictionaryWithObjectsAndKeys:@"Marked up to there.", @"completionMsg", nil];
            [nav loadRequestAndWait:seen_req];
        } else {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Not available" message:@"That feature requires you set 'Show an icon next to each post indicating if it has been seen or not' in your forum options" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
            [alert show];
            [alert release];
        }
    }   
    highlightedPost = nil;
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
        [post_box setReplyBox:thread];
        AwfulNavController *nav = getnav();
        [nav presentModalViewController:post_box animated:YES];
        [post_box release];
    } else if(option == 3) {
        if(isBookmarked) {
            [self removeBookmark];
        } else {
            [self addBookmark];
        }
    } else if(option == 4) {
        [self nextPage];
    }
}

-(void)slideToBottom
{

}

-(void)slideToTop
{
    [self scrollToRow:0];
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
    [self stop];
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
                [web loadHTMLString:post.content baseURL:[NSURL URLWithString:@""]];
            }
        }
    }
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    oldRotationRow = -1;
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
}

#pragma mark -
#pragma mark Table view data source

-(int)getTypeAtIndexPath : (NSIndexPath *)path
{
    if(path.row == 0) {
        return TITLE_BAR;
    } 
    
    if([self.renderedPosts count] > 0) {
        
        int read_posts_extra = 1;
        if([self.readPosts count] > 0) {
            read_posts_extra = 2;
        }
        
        if(path.row == 1 && [self.readPosts count] > 0) {
            return READ_POSTS_BAR;
        }
        
        if(path.row == [self.renderedPosts count] + read_posts_extra) {
            if(ad != nil) {
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
    } else if(path.row == 1 && ad != nil) {
        return AD_BAR;
    }
    
    return TITLE_BAR;
}

-(UIWebView *)getRenderedPostAtIndexPath : (NSIndexPath *)path
{
    int above_extra = 1;
    if([self.readPosts count] > 0) {
        above_extra++;
    }
    
    int index = path.row - above_extra;
    if(index < [self.renderedPosts count]) {
        return [self.renderedPosts objectAtIndex:index];
    }
    
    int type = [self getTypeAtIndexPath:path];
    if(type == AD_BAR) {
        return ad;
    }
    return nil;
}

-(NSUInteger)getRowForWebView : (UIWebView *)web
{
    int above_extra = 1;
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
    
    // title bar at top
    int rows = 1;
    if(ad != nil) {
        // ad at bottom
        rows = 2;
    }
    
    if([self.renderedPosts count] > 0) {
        // X pages left at bottom
        if(pages.current < pages.total) {
            rows++;
        }
        
        // display too short, pull to refresh gets broken
        if(pages.current == pages.total && totalFinished > 0) {
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
        case TITLE_BAR:
            height = 45;
            break;
        case READ_POSTS_BAR:
        case PAGES_LEFT_BAR:
            height = 60;
            break;
        case ITS_A_POST_YOU_IDIOT:
            web = [self getRenderedPostAtIndexPath:indexPath];
            height = CGRectGetHeight(web.frame);
            break;
        case AD_BAR:
            height = CGRectGetHeight(ad.frame);
            break;
        default:
            break;
    }
    
    // single post on page weirdness with pull to refresh
    if(pages.current == pages.total && type == ITS_A_POST_YOU_IDIOT && web == [self.renderedPosts lastObject]) {        
        float web_height = 45;
        for(UIWebView *web in self.renderedPosts) {
            web_height += web.frame.size.height;
        }
        
        if(ad != nil) {
            web_height += ad.frame.size.height;
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
    static NSString *title_ident = @"titleCell";
    static NSString *page_info_ident = @"PagesInfo";
    static NSString *read_posts_ident = @"ReadPosts";
    NSString *cell_ident = nil;
    
    int row_type = [self getTypeAtIndexPath:indexPath];
    
    if(row_type == TITLE_BAR) {
        cell_ident = title_ident;
    } else if(row_type == ITS_A_POST_YOU_IDIOT || row_type == AD_BAR) {
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
        } else if([cell_ident isEqualToString:title_ident]) {
            [cell.contentView addSubview:titleBar];
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
        if(pages.current == pages.total) {
            cell.textLabel.text = @"";
        } else if(pages.current == pages.total - 1) {
            cell.textLabel.text = @"1 page left.";
         } else {
            cell.textLabel.text = [NSString stringWithFormat:@"%d pages left.", pages.total-pages.current];
        }
        
        /*[prevPageButton removeFromSuperview];
        [nextPageButton removeFromSuperview];
        if(pages.current > 1) {
            [cell addSubview:prevPageButton];
        }
        if(pages.current < pages.total) {
            [cell addSubview:nextPageButton];
        }*/
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
    if(webView == ad) {
        return;
    }
    
    totalLoading++;
    if(totalLoading == [self.unreadPosts count]) {
        [self.tableView reloadData];
    }
}

-(BOOL)rowCheck : (int)row
{
    return row < [self.tableView numberOfRowsInSection:0];
}

-(void)webViewDidFinishLoad:(UIWebView *)sender
{
    if(sender == ad) {
        return;
    }
    
    float height = [[sender stringByEvaluatingJavaScriptFromString:@"document.body.offsetHeight"] floatValue];
    sender.frame = CGRectMake(0, 0, getWidth(), MAX(getMinHeight(), height));
    
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
    
    totalFinished++;
    if(totalFinished == [self.unreadPosts count]) {
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
    if(oldRotationRow != -1) {
        winning_row = oldRotationRow;
    } else if(newPostIndex > 1) {
        winning_row = newPostIndex;
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
        
        totalLoading = 0;
        totalFinished = 0;
        newPostIndex = 0;
        
        [self.renderedPosts removeAllObjects];
        
        for(AwfulPost *post in self.allRawPosts) {
            UIWebView *web = [self newWebViewFromAwfulPost:post];
            [self.renderedPosts addObject:web];
            [web release];
        }
        
        [self.readPosts removeAllObjects];
        [self.unreadPosts removeAllObjects];
        
        [self.unreadPosts addObjectsFromArray:self.allRawPosts];
        
        [self swapToView:stopButton];
        
        for(int i = 0; i < [self.allRawPosts count]; i++) {
            AwfulPost *post = [self.allRawPosts objectAtIndex:i];
            if(i < [self.renderedPosts count]) {
                UIWebView *web = [self.renderedPosts objectAtIndex:i];
                [web loadHTMLString:post.content baseURL:[NSURL URLWithString:@""]];
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
#pragma AwfulHistoryRecorder

-(id)newRecordedHistory
{
    AwfulHistory *hist = [[AwfulHistory alloc] init];
    hist.pageNum = pages.current;
    hist.modelObj = thread;
    hist.historyType = AWFUL_HISTORY_PAGE;
    [self setRecorder:hist];
    return hist;
}

-(id)initWithAwfulHistory : (AwfulHistory *)history
{
    return [self initWithAwfulThread:history.modelObj startAt:THREAD_POS_SPECIFIC pageNum:history.pageNum];
}

-(void)setRecorder : (AwfulHistory *)history
{
    self.pageHistory = history;
}

@end

