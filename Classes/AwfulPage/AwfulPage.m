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
#import "AwfulSmallPageController.h"
#import "AwfulSplitViewController.h"
#import "AwfulLoginController.h"
#import "AwfulVoteActions.h"
#import "AwfulPageDataController.h"
#import "AwfulNetworkEngine.h"

@implementation AwfulPage

@synthesize destinationType = _destinationType;
@synthesize thread = _thread;
@synthesize url = _url;
@synthesize isBookmarked = _isBookmarked;
@synthesize pages = _pages;
@synthesize shouldScrollToBottom = _shouldScrollToBottom;
@synthesize postIDScrollDestination = _postIDScrollDestination;
@synthesize touchedPage = _touchedPage;
@synthesize pageController = _pageController;
@synthesize dataController = _dataController;
@synthesize networkOperation = _networkOperation;
@synthesize actions = _actions;
@synthesize pagesBarButtonItem = _pagesBarButtonItem;
@synthesize nextPageBarButtonItem = _nextPageBarButtonItem;

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
        JSBridgeWebView *web = [[JSBridgeWebView alloc] initWithFrame:self.navigationController.view.frame];
        [self setWebView:web];
        [web loadHTMLString:html baseURL:[NSURL URLWithString:@"http://forums.somethingawful.com"]];
    }
}

-(void)setWebView:(JSBridgeWebView *)webView;
{
    UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(heldPost:)];
    press.delegate = self;
    press.minimumPressDuration = 0.3;
    [webView addGestureRecognizer:press];
    
    /*
    AwfulNavigator *nav = getNavigator();
    UITapGestureRecognizer *three_times = [[UITapGestureRecognizer alloc] initWithTarget:nav action:@selector(didFullscreenGesture:)];
    three_times.numberOfTapsRequired = 3;
    three_times.delegate = self;
    [webView addGestureRecognizer:three_times];
    
    UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:nav action:@selector(didFullscreenGesture:)];
    [webView addGestureRecognizer:pinch];
    pinch.delegate = self;*/
    
    webView.delegate = self;
    self.view = webView;
    
    /*
    nav.view = self.view;
    if([nav isFullscreen]) {
        nav.fullScreenButton.center = CGPointMake(nav.view.frame.size.width-25, nav.view.frame.size.height-25);
        [nav.view addSubview:nav.fullScreenButton];
    }*/
}

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
    [self.networkOperation cancel];
    [self swapToStopButton];
    self.networkOperation = [ApplicationDelegate.awfulNetworkEngine pageDataForThread:self.thread destinationType:self.destinationType pageNum:self.pages.currentPage onCompletion:^(AwfulPageDataController *dataController) {
        self.dataController = dataController;
        [self updatePagesLabel];
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
    
    if([self.view isMemberOfClass:[UIWebView class]]) {
        [(UIWebView *)self.view stopLoading];
    }
}

-(void)loadOlderPosts
{
    //int pages_left = self.pages.totalPages - self.pages.currentPage;
    //NSString *html = [AwfulParse constructPageHTMLFromPosts:self.allRawPosts pagesLeft:pages_left numOldPosts:0 adHTML:self.adHTML];
    
    NSString *html = [self.dataController constructedPageHTML];
    
    JSBridgeWebView *web = [[JSBridgeWebView alloc] initWithFrame:self.navigationController.view.frame];
    [web loadHTMLString:html baseURL:[NSURL URLWithString:@"http://forums.somethingawful.com"]];
    web.delegate = self;
    [self setWebView:web];
}

-(void)nextPage
{
    if(![self.pages onLastPage]) {
        self.destinationType = AwfulPageDestinationTypeSpecific;
        self.pages.currentPage++;
        [self refresh];
    }
}

-(void)prevPage
{
    if(self.pages.currentPage > 1) {
        self.destinationType = AwfulPageDestinationTypeSpecific;
        self.pages.currentPage--;
        [self refresh];
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
            NSMutableArray *photos = [[NSMutableArray alloc] init];
            [photos addObject:[MWPhoto photoWithURL:[NSURL URLWithString:src]]];
            
            MWPhotoBrowser *browser = [[MWPhotoBrowser alloc] initWithPhotos:photos];
            
            UIViewController *vc = getRootController();
            UINavigationController *navi = [[UINavigationController alloc] initWithRootViewController:browser];
            [vc presentModalViewController:navi animated:YES];
            
        }
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
}

- (void)viewDidUnload {
    // Relinquish ownership of anything that can be recreated in viewDidLoad or on demand.
    // For example: self.myOutlet = nil;
    [super viewDidUnload];
}

-(void)viewWillAppear:(BOOL)animated
{
    [self.navigationController setToolbarHidden:NO];
    self.navigationController.toolbar.barStyle = UIBarStyleBlack;
}

-(void)viewDidAppear:(BOOL)animated
{
    
}

#pragma mark - BarButtonItem Actions

-(void)updatePagesLabel
{
    self.pagesBarButtonItem.title = [NSString stringWithFormat:@"Page %d of %d", self.pages.currentPage, self.pages.totalPages];
    if(self.pages.currentPage == self.pages.totalPages) {
        self.nextPageBarButtonItem.enabled = NO;
    } else {
        self.nextPageBarButtonItem.enabled = YES;
    }
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

-(IBAction)tappedActions:(id)sender
{
    
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
        self.pageController = [[AwfulSmallPageController alloc] initWithAwfulPage:self];
        
        float width_diff = self.view.frame.size.width - self.pageController.view.frame.size.width;
        self.pageController.view.center = CGPointMake(self.view.center.x + width_diff/2, -self.pageController.view.frame.size.height/2);
        [self.view addSubview:self.pageController.view];
        [UIView animateWithDuration:0.3 animations:^(void) {
            self.pageController.view.frame = CGRectOffset(self.pageController.view.frame, 0, self.pageController.view.frame.size.height);
        }];
    }
}

#pragma mark -
#pragma mark Navigator Contnet

-(UIView *)getView
{
    return self.view;
}

-(AwfulActions *)getActions
{
    return [[AwfulThreadActions alloc] initWithAwfulPage:self];
}

-(void)scrollToBottom
{
    [(UIWebView *)self.view stringByEvaluatingJavaScriptFromString:@"window.scrollTo(0, document.body.scrollHeight);"];
}

-(void)scrollToSpecifiedPost
{
    [self scrollToPost:self.postIDScrollDestination];
}

-(void)scrollToPost : (NSString *)post_id
{
    if(post_id != nil) {
        NSString *scrolling = [NSString stringWithFormat:@"scrollToID(%@)", post_id];
        [(UIWebView *)self.view stringByEvaluatingJavaScriptFromString:scrolling];
    }
}

-(void)showActions:(NSString *)post_id
{    
    if(![post_id isEqualToString:@""]) {
        for(AwfulPost *post in self.dataController.posts) {
            if([post.postID isEqualToString:post_id]) {
                /*if(self.actions != nil && [self.actions isMemberOfClass:[AwfulPostActions class]]) {
                    AwfulPostActions *post_actions = (AwfulPostActions *)self.actions;
                    if(post_actions.post == post) {
                    
                    }
                }*/
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
        
        UIViewController *vc = getRootController();
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

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
}

-(void)swapToRefreshButton
{
    UIBarButtonItem *refresh = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(hardRefresh)];
    self.navigationItem.rightBarButtonItem = refresh;
}

-(void)swapToStopButton
{
    UIBarButtonItem *stop = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(stop)];
    self.navigationItem.rightBarButtonItem = stop;
}

@end


#pragma mark -
#pragma mark AwfulPageIpad

@implementation AwfulPageIpad : AwfulPage

@synthesize pageButton, popController, pagePicker;
@synthesize actions, lastTouch, ratingButton;

- (void) viewDidLoad
{
    [super viewDidLoad];
    [self makeCustomToolbars];
    [self setThreadTitle:self.thread.title];
}

- (void) viewDidUnload
{
    self.pageButton = nil;
    self.ratingButton = nil;
    self.popController = nil;
    self.pagePicker = nil;
    self.actions = nil;
    
    [super viewDidUnload];
}

-(void)makeCustomToolbars
{
    NSMutableArray *items = [NSMutableArray array];
    UIBarButtonItem *space;
    
    if (isLoggedIn()) {
        UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 140, 40)];
        
        
        UIImage *starImage;
        if (self.isBookmarked) {
            starImage = [UIImage imageNamed:@"star_on.png"];
        } else {
            starImage = [UIImage imageNamed:@"star_off.png"];
        }
        
        UIBarButtonItem *bookmark = [[UIBarButtonItem alloc] initWithImage:starImage 
                                                                     style:UIBarButtonItemStylePlain
                                                                    target:self 
                                                                    action:@selector(bookmarkThread:)];
        
        UIImage *ratingImage;
        if (self.thread.threadRating < 6)
            ratingImage = [UIImage imageNamed:[NSString stringWithFormat:@"%dstars.gif", self.thread.threadRating]];
        else
            ratingImage = [UIImage imageNamed:@"0stars.gif"];

        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        [button setBackgroundImage:ratingImage forState:UIControlStateNormal];
        button.frame = CGRectMake(0,0,ratingImage.size.width, ratingImage.size.height);
        [button addTarget:self action:@selector(rateThread:) forControlEvents:UIControlEventTouchUpInside];
        self.ratingButton = [[UIBarButtonItem alloc] initWithCustomView:button];
        

        UIBarButtonItem *reply = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCompose target:self action:@selector(reply)];
        space = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
        

        [items addObject:space];
        [items addObject:bookmark];
        [items addObject:self.ratingButton];
        [items addObject:reply];
        
        
        [toolbar setItems:items];
        
        UIBarButtonItem *toolbar_cust = [[UIBarButtonItem alloc] initWithCustomView:toolbar];
        self.navigationItem.rightBarButtonItem = toolbar_cust;
    }
    
    items = [NSMutableArray array];
    
    UIBarButtonItem *backNav = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"arrowleft-ipad.png"] style:UIBarButtonItemStylePlain target:self action:@selector(backPage)];
    
    /*AwfulNavigator *nav = getNavigator();
    if (![nav.historyManager isBackEnabled]) {
        backNav.enabled = NO;
    }*/
    
    UIBarButtonItem *refresh = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(hardRefresh)];
    
    space = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    
    UIBarButtonItem *first = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRewind target:self action:@selector(hitFirst)];
    
    if (self.pages.currentPage > 1) {
        first.enabled = NO;
    }
    
    UIBarButtonItem *prev = [[UIBarButtonItem alloc] 
                             initWithImage:[UIImage imageNamed:@"back.png"] 
                                                             style:UIBarButtonItemStylePlain 
                                                            target:self 
                                                            action:@selector(prevPage)];
    if (self.pages.currentPage > 1) {
        prev.enabled = NO;
    }
    
    NSString *pagesTitle = @"Loading...";
    if (self.pages.description) {
        pagesTitle = self.pages.description;
    }
    
    UIBarButtonItem *pages = [[UIBarButtonItem alloc] initWithTitle:pagesTitle style:UIBarButtonItemStyleBordered target:self action:@selector(pageSelection)];
    
    self.pageButton = pages;
    
    UIBarButtonItem *next = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPlay target:self action:@selector(nextPage)];
    if([self.pages onLastPage]) {
        next.enabled = NO;
    }
    
    UIBarButtonItem *last = [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemFastForward target:self action:@selector(hitLast)];
    if([self.pages onLastPage]) {
        last.enabled = NO;
    }
    
    [items addObject:backNav];
    [items addObject:refresh];
    [items addObject:space];
    [items addObject:first];
    [items addObject:prev];
    [items addObject:pages];
    [items addObject:next];
    [items addObject:last];
    
    [self setToolbarItems:items];
    
    [self.navigationController setToolbarHidden:NO animated:YES];
}

-(void)hitActions
{
    //AwfulNavigator *nav = getNavigator();
    //[nav tappedAction];
}

-(void) showActions:(NSString *)post_id
{
    
    if(![post_id isEqualToString:@""]) {
        for(AwfulPost *post in self.dataController.posts) {
            if([post.postID isEqualToString:post_id]) {
                
                AwfulPostActions *post_actions = [[AwfulPostActions alloc] initWithAwfulPost:post page:self];
                self.actions = post_actions;
                
                UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Post Actions" 
                                                                   delegate:self.actions
                                                          cancelButtonTitle:nil
                                                     destructiveButtonTitle:nil
                                                          otherButtonTitles:nil];
                for (NSString *title in actions.titles) {
                    [sheet addButtonWithTitle:title];
                }
                CGRect frame = CGRectMake(self.lastTouch.x, self.lastTouch.y, 0, 0);
                [sheet showFromRect:frame inView:self.view animated:YES];
            }
        }
    }
    
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
    /*int pageSelected = [self.pagePicker selectedRowInComponent:0] + 1;
    AwfulPage *page = [[[self class] alloc] initWithAwfulThread:self.thread startAt:AwfulPageDestinationTypeSpecific pageNum:pageSelected];
    loadContentVC(page);*/
    [self.popController dismissPopoverAnimated:YES];
}

#pragma mark -
#pragma mark Page Navigation

-(void)hitMore
{
    //AwfulExtrasController *extras = [[AwfulExtrasController alloc] init];
    //AwfulAppDelegate *del = (AwfulAppDelegate *)[[UIApplication sharedApplication] delegate];
    //[del.splitController.pageController pushViewController:extras animated:YES];
}

-(void)hitFirst
{
    //AwfulPage *first_page = [[[self class] alloc] initWithAwfulThread:self.thread startAt:AwfulPageDestinationTypeFirst];
    //loadContentVC(first_page);
}


-(void)hitLast
{
    if(![self.pages onLastPage]) {
        //AwfulPage *last_page = [[[self class] alloc] initWithAwfulThread:self.thread startAt:AwfulPageDestinationTypeLast];
        //loadContentVC(last_page);
    }
}

- (void)pageSelection
{   
    if(self.popController) {
        [self.popController dismissPopoverAnimated:YES];
        self.popController = nil;
    }
    
    self.pagePicker = [[UIPickerView alloc] initWithFrame:CGRectMake(0, 0, 320, 216)];
    self.pagePicker.dataSource = self;
    self.pagePicker.delegate = self;
    [self.pagePicker selectRow:[self.pages currentPage]-1
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
    self.popController = [[UIPopoverController alloc] initWithContentViewController:vc];
    
    [self.popController setPopoverContentSize:view.frame.size animated:YES];
    [self.popController presentPopoverFromBarButtonItem:self.pageButton 
                               permittedArrowDirections:UIPopoverArrowDirectionAny
                                               animated:YES];
}

-(void)hitForum
{
    if(self.thread.forum != nil) {
        /*AwfulThreadListIpad *list = [[AwfulThreadListIpad alloc] initWithAwfulForum:self.thread.forum];
        loadContentVC(list);*/
    }
}

-(void)backPage
{
    //AwfulNavigator *nav = getNavigator();
    //[nav tappedBack];
    
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
    [self makeCustomToolbars];
    UIButton *titleButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [titleButton setTitle:in_title forState:UIControlStateNormal];
    [titleButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [titleButton setTitleColor:[UIColor blackColor] forState:UIControlStateHighlighted];
    [titleButton setTitleColor:[UIColor blackColor] forState:UIControlStateSelected];
    [titleButton setTitleColor:[UIColor blackColor] forState:UIControlStateDisabled];
    
    [titleButton addTarget:self action:@selector(hitForum) forControlEvents:UIControlEventTouchUpInside];
    
    titleButton.frame = CGRectMake(0, 0, getWidth()-50, 44);
    
    self.navigationItem.titleView = titleButton;
}

-(void)setWebView:(JSBridgeWebView *)webView
{
    [super setWebView:webView];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    tap.delegate = self;
    [webView addGestureRecognizer:tap];
    
}

- (void)handleTap:(UITapGestureRecognizer *)sender 
{     
    if (sender.state == UIGestureRecognizerStateEnded) {    
        self.lastTouch = [sender locationInView:self.view];
    } 
}

-(void)rateThread:(id)sender
{
    
    if(self.popController) {
        [self.popController dismissPopoverAnimated:YES];
        self.popController = nil;
    }

    AwfulVoteActions *vote_actions = [[AwfulVoteActions alloc] initWithAwfulThread:self.thread];
    self.actions = vote_actions;
    
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil
                                                       delegate:self.actions
                                              cancelButtonTitle:nil
                                         destructiveButtonTitle:nil
                                              otherButtonTitles:nil];
    for (NSString *title in self.actions.titles) {
        [sheet addButtonWithTitle:title];
    }
    [sheet showFromBarButtonItem:self.ratingButton animated:YES];
    
}

-(void)bookmarkThread:(id)sender;
{
    AwfulThreadActions *thread_actions = [[AwfulThreadActions alloc] initWithAwfulPage:self];
    UIBarButtonItem *button = (UIBarButtonItem *) sender;
    
    if (self.isBookmarked) {
        button.image = [UIImage imageNamed:@"star_off.png"];
        [thread_actions removeBookmark];
    } else {
        button.image = [UIImage imageNamed:@"star_on.png"];
        [thread_actions addBookmark];
    }
}

-(void)reply
{
    AwfulPostBoxController *post_box = [[AwfulPostBoxController alloc] initWithText:@""];
    [post_box setThread:self.thread];
    UIViewController *vc = getRootController();
    [vc presentModalViewController:post_box animated:YES];
}

@end
