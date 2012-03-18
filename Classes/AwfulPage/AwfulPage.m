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
#import "Appirater.h"
#import "AwfulPageCount.h"
#import "AwfulConfig.h"
#import "AwfulThreadActions.h"
#import "AwfulPostActions.h"
#import "MWPhoto.h"
#import "MWPhotoBrowser.h"
#import <QuartzCore/QuartzCore.h>
#import "AwfulUser.h"
#import "AwfulSpecificPageViewController.h"
#import "AwfulSplitViewController.h"
#import "AwfulLoginController.h"
#import "AwfulVoteActions.h"
#import "AwfulPageDataController.h"
#import "AwfulNetworkEngine.h"

@implementation AwfulPage

@synthesize destinationType = _destinationType;
@synthesize thread = _thread;
@synthesize url = _url;
@synthesize webView = _webView;
@synthesize bottomView = _bottomView;
@synthesize toolbar = _toolbar;
@synthesize isBookmarked = _isBookmarked;
@synthesize pages = _pages;
@synthesize shouldScrollToBottom = _shouldScrollToBottom;
@synthesize postIDScrollDestination = _postIDScrollDestination;
@synthesize touchedPage = _touchedPage;
@synthesize specificPageController = _specificPageController;
@synthesize dataController = _dataController;
@synthesize networkOperation = _networkOperation;
@synthesize actions = _actions;
@synthesize pagesBarButtonItem = _pagesBarButtonItem;
@synthesize nextPageBarButtonItem = _nextPageBarButtonItem;
@synthesize draggingUp = _draggingUp;

#pragma mark -
#pragma mark Initialization

-(void)awakeFromNib
{    
}

-(void)setThread:(AwfulThread *)newThread
{
    if(_thread != newThread) {
        _thread = newThread;
        if(_thread.title != nil) {
            UILabel *lab = (UILabel *)self.navigationItem.titleView;
            lab.text = self.thread.title;
            NSLog(@"title width %f", self.navigationItem.titleView.frame.size.width);
        }
        
        if(_thread.totalUnreadPosts == -1) {
            self.destinationType = AwfulPageDestinationTypeFirst;
        } else if(_thread.totalUnreadPosts == 0) {
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
        self.pages = dataController.pageCount;
        [self setThreadTitle:dataController.threadTitle];
        
        self.postIDScrollDestination = [dataController calculatePostIDScrollDestination];
        self.shouldScrollToBottom = [dataController shouldScrollToBottom];
        if(self.destinationType != AwfulPageDestinationTypeNewpost) {
            self.shouldScrollToBottom = NO;
        }
        
        NSString *html = [dataController constructedPageHTML];
        [self.webView loadHTMLString:html baseURL:[NSURL URLWithString:@"http://forums.somethingawful.com"]];
    }
}


/*
-(void)setWebView:(JSBridgeWebView *)webView;
{
    UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(heldPost:)];
    press.delegate = self;
    press.minimumPressDuration = 0.3;
    [webView addGestureRecognizer:press];
    
    
    AwfulNavigator *nav = getNavigator();
    UITapGestureRecognizer *three_times = [[UITapGestureRecognizer alloc] initWithTarget:nav action:@selector(didFullscreenGesture:)];
    three_times.numberOfTapsRequired = 3;
    three_times.delegate = self;
    [webView addGestureRecognizer:three_times];
    
    UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:nav action:@selector(didFullscreenGesture:)];
    [webView addGestureRecognizer:pinch];
    pinch.delegate = self;
    
    
    nav.view = self.view;
    if([nav isFullscreen]) {
        nav.fullScreenButton.center = CGPointMake(nav.view.frame.size.width-25, nav.view.frame.size.height-25);
        [nav.view addSubview:nav.fullScreenButton];
    }
}*/

-(void)setPages:(AwfulPageCount *)in_pages
{
    if(_pages != in_pages) {
        _pages = in_pages;
        [self updatePagesLabel];
    }
}

-(void)setThreadTitle : (NSString *)title
{
    [self.thread setTitle:title];
    UILabel *lab = (UILabel *)self.navigationItem.titleView;
    lab.text = title;
    NSLog(@"title width %f", self.navigationItem.titleView.frame.size.width);
}

-(IBAction)hardRefresh
{    
    int posts_per_page = getPostsPerPage();
    if([self.pages onLastPage] && [self.dataController.posts count] == posts_per_page) {
        self.destinationType = AwfulPageDestinationTypeSpecific;
        [self refresh];
    } else {
        self.destinationType = AwfulPageDestinationTypeNewpost;
        [self refresh];
    }
}

-(void)refresh
{        
    [self loadPageNum:self.pages.currentPage];
}

-(void)loadPageNum : (NSUInteger)pageNum
{    
    [self.networkOperation cancel];
    [self swapToStopButton];
    self.networkOperation = [ApplicationDelegate.awfulNetworkEngine pageDataForThread:self.thread destinationType:self.destinationType pageNum:pageNum onCompletion:^(AwfulPageDataController *dataController) {
        self.dataController = dataController;
        if(self.destinationType == AwfulPageDestinationTypeSpecific) {
            self.pages.currentPage = pageNum;
        }
        [self updatePagesLabel];
        [self swapToRefreshButton];
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
    
    [self.webView stopLoading];
}

-(void)loadOlderPosts
{
    //int pages_left = self.pages.totalPages - self.pages.currentPage;
    //NSString *html = [AwfulParse constructPageHTMLFromPosts:self.allRawPosts pagesLeft:pages_left numOldPosts:0 adHTML:self.adHTML];
    
    NSString *html = [self.dataController constructedPageHTML];
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
            
            UIViewController *vc = [ApplicationDelegate getRootController];
            UINavigationController *navi = [[UINavigationController alloc] initWithRootViewController:browser];
            [vc presentModalViewController:navi animated:YES];
            
        }
    }
}

-(void)setActions:(AwfulPostActions *)actions
{
    if(actions != _actions) {
        _actions = actions;
        _actions.viewController = self;
        [_actions show];
    }
}

#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Relinquish ownership any cached data, images, etc that aren't in use.
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(heldPost:)];
    press.delegate = self;
    press.minimumPressDuration = 0.3;
    [self.webView addGestureRecognizer:press];
    self.webView.delegate = self;
    
    [self.nextPageBarButtonItem setTintColor:[UIColor whiteColor]];
    NSDictionary *attr = [NSDictionary dictionaryWithObject:[UIColor whiteColor] forKey:UITextAttributeTextColor];
    [self.pagesBarButtonItem setTitleTextAttributes:attr forState:UIControlStateDisabled];
    
    
    UISwipeGestureRecognizer *swipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swiped:)];
    [self.bottomView addGestureRecognizer:swipe];
}

- (void)viewDidUnload {
    // Relinquish ownership of anything that can be recreated in viewDidLoad or on demand.
    // For example: self.myOutlet = nil;
    [super viewDidUnload];
}

-(void)viewWillAppear:(BOOL)animated
{
    [self.navigationController setToolbarHidden:YES];
    self.navigationController.toolbar.barStyle = UIBarStyleBlack;
}

-(void)viewDidAppear:(BOOL)animated
{
    
}

#pragma mark - BarButtonItem Actions

-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    CGPoint loc = [touch locationInView:self.view];
    CGRect frame = self.bottomView.frame;
    CGFloat potential_y = loc.y-22;
    potential_y = MIN(self.view.frame.size.height-44, potential_y);
    potential_y = MAX(self.view.frame.size.height-self.bottomView.frame.size.height, potential_y);
    frame.origin.y = potential_y;
    [self.bottomView setFrame:frame];
    
    CGPoint last_loc = [touch previousLocationInView:self.view];
    if(last_loc.y > loc.y) {
        self.draggingUp = YES;
    } else {
        self.draggingUp = NO;
    }
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if(self.draggingUp) {
        if(self.bottomView.frame.origin.y != [self getRevealedBottomViewY]) {
            [self revealBottomView:nil];
        }
    } else {
        if(self.bottomView.frame.origin.y != [self getHiddenBottomViewY]) {
            [self hideBottomView:nil];
        }
    }
}

-(void)swiped : (UISwipeGestureRecognizer *)swiper
{
    if(swiper.state == UIGestureRecognizerStateEnded) {
        if(swiper.direction == UISwipeGestureRecognizerDirectionDown) {
            [self hideBottomView:nil];
        } else if(swiper.direction == UISwipeGestureRecognizerDirectionUp) {
            [self revealBottomView:nil];
        }
    }
}
       
-(CGFloat)getHiddenBottomViewY
{
    return self.view.frame.size.height-44;
}

-(CGFloat)getRevealedBottomViewY
{
    return self.view.frame.size.height-self.bottomView.frame.size.height;
}

-(IBAction)revealBottomView : (id)sender
{
    [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationCurveEaseInOut animations:^(void){
        
        CGFloat y = [self getRevealedBottomViewY];
        CGRect frame = self.bottomView.frame;
        frame.origin.y = y;
        self.bottomView.frame = frame;
        
    } completion:^(BOOL finished) {
        
    }];
}

-(IBAction)hideBottomView : (id)sender
{
    [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationCurveEaseInOut animations:^(void){
        
        CGFloat y = [self getHiddenBottomViewY];
        CGRect frame = self.bottomView.frame;
        frame.origin.y = y;
        self.bottomView.frame = frame;
        
    } completion:^(BOOL finished) {
        
    }];
}

-(void)updatePagesLabel
{
    self.pagesBarButtonItem.title = [NSString stringWithFormat:@"Page %d of %d", self.pages.currentPage, self.pages.totalPages];
    if(self.pages.currentPage == self.pages.totalPages) {
        self.nextPageBarButtonItem.enabled = NO;
    } else {
        self.nextPageBarButtonItem.enabled = YES;
    }
    NSDictionary *attr = [NSDictionary dictionaryWithObject:[UIColor whiteColor] forKey:UITextAttributeTextColor];
    [self.pagesBarButtonItem setTitleTextAttributes:attr forState:UIControlStateDisabled];
}

-(IBAction)tappedBookmarks : (id)sender
{
    
}

-(IBAction)tappedVote : (id)sender
{
    
}

-(IBAction)tappedCompose : (id)sender
{
    
}

-(IBAction)tappedNextPage : (id)sender
{
    [self nextPage];
}

-(void)nextPage
{
    if(![self.pages onLastPage]) {
        self.destinationType = AwfulPageDestinationTypeSpecific;
        [self loadPageNum:self.pages.currentPage+1];
    }
}

-(void)prevPage
{
    if(self.pages.currentPage > 1) {
        self.destinationType = AwfulPageDestinationTypeSpecific;
        [self loadPageNum:self.pages.currentPage-1];
    }
}

-(IBAction)tappedActions:(id)sender
{
    AwfulThreadActions *actions = [[AwfulThreadActions alloc] initWithAwfulPage:self];
    self.actions = actions;
}

-(void)tappedPageNav : (id)sender
{
    UIView *sp_view = self.specificPageController.containerView;
    
    if(self.specificPageController != nil && !self.specificPageController.hiding) {
        
        self.specificPageController.hiding = YES;
        [UIView animateWithDuration:0.3 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^(void) {
            sp_view.frame = CGRectOffset(sp_view.frame, 0, sp_view.frame.size.height);
        } completion:^(BOOL finished) {
            [sp_view removeFromSuperview];
            self.specificPageController = nil;
        }];
        
    } else if(self.specificPageController == nil) {
        
        self.specificPageController = [[UIStoryboard storyboardWithName:@"MainStoryboard" bundle:nil] instantiateViewControllerWithIdentifier:@"AwfulSpecificPageController"];
        self.specificPageController.page = self;
        [self.specificPageController loadView];
        sp_view = self.specificPageController.containerView;
        
        float width_diff = self.view.frame.size.width - sp_view.frame.size.width;
        sp_view.center = CGPointMake(self.view.center.x + width_diff/2, self.view.frame.size.height+sp_view.frame.size.height/2);
        [self.view addSubview:sp_view];
        [UIView animateWithDuration:0.3 animations:^(void) {
            sp_view.frame = CGRectOffset(sp_view.frame, 0, -sp_view.frame.size.height);
        }];
        
        [self.specificPageController.pickerView selectRow:self.pages.currentPage-1 inComponent:0 animated:NO];
    }
}

#pragma mark -
#pragma mark Navigator Contnet

-(AwfulActions *)getActions
{
    return [[AwfulThreadActions alloc] initWithAwfulPage:self];
}

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
        NSString *scrolling = [NSString stringWithFormat:@"scrollToID(%@)", post_id];
        [self.webView stringByEvaluatingJavaScriptFromString:scrolling];
    }
}

-(void)showActions:(NSString *)post_id
{    
    if(![post_id isEqualToString:@""]) {
        for(AwfulPost *post in self.dataController.posts) {
            if([post.postID isEqualToString:post_id]) {
                AwfulPostActions *actions = [[AwfulPostActions alloc] initWithAwfulPost:post page:self];
                self.actions = actions;
            }
        }
    }
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
            
            NSString *post_id = [dictionary objectForKey:@"postid"];
            [self showActions:post_id];
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
                
                //AwfulPage *page = nil;
                
                /*
                if(page_number == nil) {
                    page = [[[self class] alloc] initWithAwfulThread:intra startAt:AwfulPageDestinationTypeFirst];
                } else {
                    page = [[[self class] alloc] initWithAwfulThread:intra startAt:AwfulPageDestinationTypeSpecific pageNum:[page_number intValue]];
                    int pti = [AwfulParse getNewPostNumFromURL:request.URL];
                    page.url = [NSString stringWithFormat:@"showthread.php?threadid=%@&pagenumber=%@#pti%d", thread_id, page_number, pti];
                }
                
                
                if(page != nil) {
                    loadContentVC(page);
                    return NO;
                }*/
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
        
        UIViewController *vc = [ApplicationDelegate getRootController];
        [vc presentModalViewController:other_nav animated:YES];
        
        return NO;
    }
    return YES;
}

-(void)webViewDidFinishLoad:(UIWebView *)sender
{
    [self swapToRefreshButton];
    if(!self.touchedPage) {
        if(self.postIDScrollDestination != nil) {
            [self scrollToSpecifiedPost];
        } else if(self.shouldScrollToBottom) {
            [self scrollToBottom];
        }
    }
}

-(void)webViewDidStartLoad:(UIWebView *)webView
{
    
}

-(void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
}

-(void)swapToRefreshButton
{
    UIBarButtonItem *refresh = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(hardRefresh)];
    refresh.style = UIBarButtonItemStylePlain;
    [refresh setTintColor:[UIColor whiteColor]];
    NSMutableArray *items = [NSMutableArray arrayWithArray:self.toolbar.items];
    if([items count] > 0) {
        [items replaceObjectAtIndex:0 withObject:refresh];
        [self.toolbar setItems:items animated:NO];
    }
}

-(void)swapToStopButton
{
    UIBarButtonItem *stop = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(stop)];
    stop.style = UIBarButtonItemStylePlain;
    [stop setTintColor:[UIColor whiteColor]];
    NSMutableArray *items = [NSMutableArray arrayWithArray:self.toolbar.items];
    if([items count] > 0) {
        [items replaceObjectAtIndex:0 withObject:stop];
        [self.toolbar setItems:items animated:NO];
    }
}

@end
