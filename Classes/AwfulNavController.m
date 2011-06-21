    //
//  AwfulNavController.m
//  Awful
//
//  Created by Sean Berry on 7/26/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulNavController.h"
#import "AwfulForumsList.h"
#import "AwfulWebCache.h"
#import "AwfulAppDelegate.h"
#import "AwfulPage.h"
#import "AwfulUtil.h"
#import "AwfulThreadList.h"
#import "BookmarksController.h"
#import "AwfulConfig.h"
#import "OtherWebController.h"
#import "AwfulHistory.h"
#import "MWPhoto.h"
#import "MWPhotoBrowser.h"
#import "AwfulPageCount.h"

@implementation AwfulNavController

@synthesize queue, user, bookmarksRefreshReq;
@synthesize recordedHistory = _recordedHistory;
@synthesize recordedForwardHistory = _recordedForwardHistory;
@synthesize hud = _hud;

 // The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
-(id)initWithCoder:(NSCoder *)aDecoder
{
    if((self = [super initWithCoder:aDecoder])) {
        // Custom initialization
        
        bookmarksRefreshReq = nil;
        pageNav = nil;
        vote = [[VoteDelegate alloc] init];
        queue = [[ASINetworkQueue alloc] init];
        history = [[NSMutableArray alloc] init];
        forwardHistory = [[NSMutableArray alloc] init];
        _recordedHistory = [[NSMutableArray alloc] init];
        _recordedForwardHistory = [[NSMutableArray alloc] init];
        self.hud = nil;
        
        AwfulForum *empty_forum = [[AwfulForum alloc] init];
        AwfulThreadList *blank = [[AwfulThreadList alloc] initWithAwfulForum:empty_forum];
        [self pushViewController:blank animated:NO];
        [blank release];
        [empty_forum release];
        
        user = [[AwfulUser alloc] init];
        [user loadUser];
        
        displayingPostOptions = NO;
        unfiltered = [[UIViewController alloc] init];
        unfiltered.title = @"Raw";
        
        back = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"icon_arrow_left.png"] style:UIBarButtonItemStylePlain target:self action:@selector(goBack)];
        forward = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"icon_arrow_right.png"] style:UIBarButtonItemStylePlain target:self action:@selector(goForward)];
        bookmarks = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemBookmarks target:self action:@selector(openBookmarks)];
        options = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(openOptions)];
        forumsList = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"list_icon.png"] style:UIBarButtonItemStylePlain target:self action:@selector(openForums)];
        
        float w = 30;
        back.width = w;
        forward.width = w;
        bookmarks.width = w;
        options.width = w;
        forumsList.width = w;
    }
    return self;
}

-(void)dealloc {
    [bookmarksRefreshReq release];
    [vote release];
    [queue release];
    [forwardHistory release];
    [history release];
    [login release];
    [back release];
    [forward release];
    [bookmarks release];
    [options release];
    [forumsList release];
    [user release];
    
    [_recordedHistory release];
    _recordedHistory = nil;
    [_recordedForwardHistory release];
    _recordedForwardHistory = nil;
    
    [_hud release];
    _hud = nil;
    
    [super dealloc];
}

/*
// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView {
}
*/

-(void)stopAllRequests
{
    [queue setShouldCancelAllRequestsOnFailure:NO];
    [queue cancelAllOperations];
}

-(void)addHistory : (id<AwfulHistoryRecorder>)obj
{
    [history addObject:obj];
    AwfulHistory *record = [obj newRecordedHistory];
    [self.recordedHistory addObject:record];
    [record release];
    
    if([history count] > MAX_HISTORY) {
        [history removeObjectAtIndex:0];
    }
    
    if([self.recordedHistory count] > MAX_RECORDED_HISTORY) {
        [self.recordedHistory removeObjectAtIndex:0];
    }
    
    [forwardHistory removeAllObjects];
    [self.recordedForwardHistory removeAllObjects];
    [self checkHistoryButtons];
}

-(void)showNotification : (NSString *)msg
{
    float width = getWidth();

    UIFont *f = [UIFont fontWithName:@"Helvetica" size:18.0];
    UILabel *lab = [[UILabel alloc] initWithFrame:CGRectMake(0, -20, 300, 40)];
    lab.text = msg;
    lab.font = f;
    lab.center = CGPointMake(width/2, -10);
    lab.textAlignment = UITextAlignmentCenter;
    
    [self.view addSubview:lab];
    
    [UIView animateWithDuration:1.0 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^(void){
        lab.transform = CGAffineTransformMakeTranslation(0, 50);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:1.0 delay:3.0 options:UIViewAnimationOptionCurveEaseIn animations:^(void) {
            lab.transform = CGAffineTransformMakeTranslation(0, -50);
        } completion:^(BOOL finished) {
            lab.center = CGPointMake(width/2, -50);
            [lab removeFromSuperview];
        }];
    }];
}

-(void)requestFinished : (ASIHTTPRequest *)request
{
    if(self.hud != nil) {
        NSString *msg = [request.userInfo objectForKey:@"completionMsg"];
        if(msg != nil) {
            self.hud.customView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Checkmark.png"]] autorelease];
            self.hud.mode = MBProgressHUDModeCustomView;
            self.hud.labelText = msg;
            [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(hideHud) userInfo:nil repeats:NO];
        } else {
            [self hideHud];
        }
    }
    
    id<WaitRequestCallback> obj = nil;
    obj = [request.userInfo objectForKey:@"waitCallback"];
    if(obj != nil) {
        [obj success];
    }
    
    NSNumber *ref = [request.userInfo objectForKey:@"refresh"];
    if(ref != nil) {
        if([ref boolValue]) {
            
            UIViewController *vc = [self.viewControllers lastObject];
            
            if([vc isMemberOfClass:[AwfulPage class]]) {
                AwfulPage *page = (AwfulPage *)vc;
                [page refresh];
            } else if([vc isKindOfClass:[AwfulThreadList class]]) {
                AwfulThreadList *list = (AwfulThreadList *)vc;
                [list refresh];
            }
        }
    }
}

-(void)requestFailed : (ASIHTTPRequest *)request
{
    id<WaitRequestCallback> obj = [request.userInfo objectForKey:@"callback"];
    if(obj != nil) {
        [obj failed];
    }
    
    if(self.hud != nil) {
        self.hud.mode = MBProgressHUDModeCustomView;
        self.hud.labelText = @"Failed";
        [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(hideHud) userInfo:nil repeats:NO];
    }
}

-(void)hideHud
{
    [self.hud removeFromSuperview];
    self.hud = nil;
}

-(void)loadRequest : (ASIHTTPRequest *)req
{   
    [[self queue] addOperation:req];
    [req setDelegate:self];
    [queue go];
}

-(void)loadRequestAndWait : (ASIHTTPRequest *)req
{
    UIView *v = self.view;
    
    if(self.modalViewController != nil) {
        v = self.modalViewController.view;
    }
    
    self.hud = [[[MBProgressHUD alloc] initWithView:v] autorelease];
    [v addSubview:self.hud];
    self.hud.delegate = self;
    self.hud.mode = MBProgressHUDModeIndeterminate;
    self.hud.labelText = @"Loading...";
    [self.hud show:YES];
    [[self queue] addOperation:req];
    [req setDelegate:self];
    [queue go];
}

-(void)loadPage : (AwfulPage *)page
{
    [self dismissModalViewControllerAnimated:YES];
    
    [page refresh];
    
    [self addHistory:page];
    NSMutableArray *temp_array = [NSMutableArray arrayWithArray:history];
    [temp_array removeLastObject];
    self.viewControllers = temp_array;
    
    [self pushViewController:page animated:YES];
}

-(void)loadForum : (AwfulThreadList *)forum
{
    [self dismissModalViewControllerAnimated:YES];
    
    [self addHistory:forum];
    
    self.viewControllers = [NSArray arrayWithObjects:[self.viewControllers lastObject], nil];
    
    [self pushViewController:forum animated:YES];
}

-(void)showImage : (NSString *)img_src
{
    NSMutableArray *photos = [[NSMutableArray alloc] init];
    [photos addObject:[MWPhoto photoWithURL:[NSURL URLWithString:img_src]]];
    
    //[self setNavigationBarHidden:NO animated:YES];
    
    //[self setToolbarHidden:YES animated:YES];
    
    
    
    MWPhotoBrowser *browser = [[MWPhotoBrowser alloc] initWithPhotos:photos];
    
    UINavigationController *navi = [[UINavigationController alloc] initWithRootViewController:browser];
    [self presentModalViewController:navi animated:YES];
    [navi release];
    
    //[self pushViewController:browser animated:YES];
    
    [browser release];
    [photos release];
}

-(void)goBack
{
    if([history count] == 0) {
        return;
    }

    id<AwfulHistoryRecorder> obj = [[history lastObject] retain];
    [history removeLastObject];
    [self.recordedHistory removeLastObject];
    
    if([history count] > 0) {
        self.viewControllers = [NSArray arrayWithObjects:[history lastObject], obj, nil];
    } else {
        AwfulHistory *patch_record = [self.recordedHistory lastObject];
        id patch_controller = [patch_record newThreadObj];
        self.viewControllers = [NSArray arrayWithObjects:patch_controller, obj, nil];
        [history addObject:patch_controller];
        [patch_controller release];
    }
    
    AwfulHistory *forward_record = [obj newRecordedHistory];
    [self.recordedForwardHistory addObject:forward_record];
    [forward_record release];
    
    [obj release];
    
    id old_view_controller = [self.viewControllers lastObject];
    [forwardHistory addObject:old_view_controller];
    if([forwardHistory count] > MAX_HISTORY-1) {
        [forwardHistory removeObjectAtIndex:0];
    }
    [self popViewControllerAnimated:YES];
    [self checkHistoryButtons];
}

-(void)goForward
{
    if([forwardHistory count] == 0 && [self.recordedForwardHistory count] == 0) {
        return;
    }
    
    if([forwardHistory count] > 0) {
        id<AwfulHistoryRecorder> obj = [[forwardHistory lastObject] retain];
        [forwardHistory removeLastObject];
    
        [history addObject:obj];
        AwfulHistory *record = [obj newRecordedHistory];
        [self.recordedHistory addObject:record];
        [record release];
        [self.recordedForwardHistory removeLastObject];
        
        [self pushViewController:(UIViewController *)obj animated:YES];
        
        [obj release];
    } else {
        
        AwfulHistory *forward_record = [[self.recordedForwardHistory lastObject] retain];
        [self.recordedForwardHistory removeLastObject];
        id view_controller = [forward_record newThreadObj];
        
        [history addObject:view_controller];
        [self.recordedHistory addObject:forward_record];        
        
        [self pushViewController:view_controller animated:YES];
        [forward_record release];
    }
    
    if([history count] > MAX_HISTORY) {
        [history removeObjectAtIndex:0];
    }
    
    [self checkHistoryButtons];
}

-(void)openOptions
{
    if([[history lastObject] isMemberOfClass:[AwfulPage class]]) {
        [self showThreadOptions];
    } else if([[history lastObject] isMemberOfClass:[AwfulThreadList class]]) {
        [self showForumOptions];
    }
}

-(void)openForums
{
    AwfulForumsList *forums = [[AwfulForumsList alloc] initWithStyle:UITableViewStyleGrouped];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:forums];
    if([AwfulConfig isColorSchemeBlack]) {
        nav.navigationBar.barStyle = UIBarStyleBlack;
    } else {
        nav.navigationBar.barStyle = UIBarStyleDefault;
    }
    [self presentModalViewController:nav animated:YES];
    [nav release];
    [forums release];
}

-(void)openBookmarks
{
    BookmarksController *book = [[BookmarksController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:book];
    if([AwfulConfig isColorSchemeBlack]) {
        nav.navigationBar.barStyle = UIBarStyleBlack;
    } else {
        nav.navigationBar.barStyle = UIBarStyleDefault;
    }
    [self presentModalViewController:nav animated:YES];
    [nav release];
    [book release];
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
    [self setNavigationBarHidden:YES];
    [self checkHistoryButtons];
}

-(void)checkHistoryButtons
{
    if([forwardHistory count] == 0 && [self.recordedForwardHistory count] == 0) {
        forward.enabled = NO;
    } else {
        forward.enabled = YES;
    }
    
    if([history count] <= 1 && [self.recordedHistory count] <= 1) {
        back.enabled = NO;
    } else {
        back.enabled = YES;
    }
}

-(NSArray *)getToolbarItemsForOrientation : (UIInterfaceOrientation)orient
{    
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];

    NSArray *items = [NSArray arrayWithObjects:back, flex, forward, flex, options, flex, bookmarks, flex, forumsList, nil];    
    [flex release];

    return items;
}

-(NSArray *)getToolbarItems
{
    return [self getToolbarItemsForOrientation:[[UIApplication sharedApplication] statusBarOrientation]];
}

-(void)showLogin
{
    AwfulAppDelegate *del = (AwfulAppDelegate *)[[UIApplication sharedApplication] delegate];
    [del disableCache];
    login = [[LoginController alloc] initWithNibName:@"LoginController" bundle:[NSBundle mainBundle] controller:self];
    [self dismissModalViewControllerAnimated:NO];
    [self presentModalViewController:login animated:NO];
}

-(BOOL)isLoggedIn
{
    NSURL *awful_url = [NSURL URLWithString:@"http://forums.somethingawful.com"];
    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:awful_url];
    
    BOOL logged_in = NO;
    
    for(NSHTTPCookie *cookie in cookies) {
        if([cookie.name isEqualToString:@"bbuserid"]) {
            logged_in = YES;
        }
    }
    return logged_in;
}

-(void)tappedTop
{
    if([self.visibleViewController isMemberOfClass:[AwfulPage class]]) {
        AwfulPage *page = (AwfulPage *)self.visibleViewController;
        [page slideUp];
    }
}

-(void)tappedBottom
{
    if([self.visibleViewController isMemberOfClass:[AwfulPage class]]) {
        AwfulPage *page = (AwfulPage *)self.visibleViewController;
        [page slideDown];
    }
}

-(void)doubleTappedTop
{
    if([self.visibleViewController isMemberOfClass:[AwfulPage class]]) {
        //AwfulPage *page = (AwfulPage *)self.visibleViewController;
        //[page slideToTop];
    }
}

-(void)doubleTappedBottom
{
    if([self.visibleViewController isMemberOfClass:[AwfulPage class]]) {
        //AwfulPage *page = (AwfulPage *)self.visibleViewController;
        //[page slideToBottom];
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if([[history lastObject] isMemberOfClass:[AwfulPage class]]) {
        if([self.visibleViewController isMemberOfClass:[AwfulPage class]]) {
            AwfulPage *current_page = (AwfulPage *)self.visibleViewController;
            if(displayingPostOptions) {
                [current_page chosePostOption:buttonIndex];
            } else {
                [current_page choseThreadOption:buttonIndex];
            }
        }
    } else if([[history lastObject] isMemberOfClass:[AwfulThreadList class]]) {
        if([self.visibleViewController isMemberOfClass:[AwfulThreadList class]]) {
            AwfulThreadList *current_list = (AwfulThreadList *)self.visibleViewController;
            [current_list choseForumOption:buttonIndex];
        }
    }
    
    displayingPostOptions = NO;
}

-(void)showVoteOptions : (AwfulPage *)page
{
    [vote setThread:page.thread];
    
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:[NSString stringWithFormat:@"Vote: %@", page.thread.title] delegate:vote cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
    [sheet addButtonWithTitle:@"5"];
    [sheet addButtonWithTitle:@"4"];
    [sheet addButtonWithTitle:@"3"];
    [sheet addButtonWithTitle:@"2"];
    [sheet addButtonWithTitle:@"1"];
    [sheet addButtonWithTitle:@"Cancel"];
    sheet.cancelButtonIndex = 5;
    [sheet showInView:self.view];
    [sheet release];
}

-(void)showForumOptions
{
    AwfulThreadList *list = (AwfulThreadList *)[history lastObject];
    
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:[NSString stringWithFormat:@"Current Page %d", list.pages.currentPage] delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
    
    int cancel = 1;
    if(list.pages.currentPage > 1) {
        [sheet addButtonWithTitle:@"Previous Page"];
        cancel = 2;
    }
    [sheet addButtonWithTitle:@"Next Page"];
    [sheet addButtonWithTitle:@"Cancel"];
    sheet.cancelButtonIndex = cancel;
    [sheet showInView:self.view];
    [sheet release];
}

-(void)showPostOptions : (AwfulPost *)p
{
    if(!displayingPostOptions) {
        displayingPostOptions = YES;
        
        UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:[NSString stringWithFormat:@"%@'s Post Options", p.authorName] delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
        
        if(p.canEdit) {
            [sheet addButtonWithTitle:@"Edit"];
        }
        [sheet addButtonWithTitle:@"Quote"];
        [sheet addButtonWithTitle:@"View Original Formatting"];
        [sheet addButtonWithTitle:@"Mark read up to here"];
        [sheet addButtonWithTitle:@"Cancel"];
        if(p.canEdit) {
            sheet.cancelButtonIndex = 4;
        } else {
            sheet.cancelButtonIndex = 3;
        }
        [sheet showInView:self.view];
        [sheet release];
    }
}

-(void)showThreadOptions
{
    AwfulPage *thread = (AwfulPage *)[history lastObject];
    BOOL on_last_page = thread.pages.currentPage < thread.pages.totalPages;
    int cancel_index = 4;
    
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:[NSString stringWithFormat:@"Thread Actions: Current Page %d/%d", thread.pages.currentPage, thread.pages.totalPages] delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
    
    [sheet addButtonWithTitle:@"Specific Page"];
    [sheet addButtonWithTitle:@"Vote"];
    [sheet addButtonWithTitle:@"Reply"];
    
    if(thread.isBookmarked) {
        [sheet addButtonWithTitle:@"Remove From Bookmarks"];
    } else {
        [sheet addButtonWithTitle:@"Add To Bookmarks"];
    }
    
    if(on_last_page) {
        [sheet addButtonWithTitle:@"Next Page"];
        cancel_index = 5;
    }
    [sheet addButtonWithTitle:@"Cancel"];
    sheet.cancelButtonIndex = cancel_index;
    [sheet showInView:self.view];
    [sheet release];
}

-(void)showPageNumberNav : (AwfulPage *)page
{
    pageNav = [[AwfulPageNavController alloc] initWithAwfulPage:page];
    pageNav.view.frame = CGRectMake(0, CGRectGetHeight(self.view.frame)-CGRectGetHeight(pageNav.view.frame), CGRectGetWidth(self.view.frame), CGRectGetHeight(pageNav.view.frame));
    if(UIInterfaceOrientationIsPortrait([[UIApplication sharedApplication] statusBarOrientation])) {
        pageNav.view.frame = CGRectMake(0, 480-250, 320, 250);
    } else {
        pageNav.view.frame = CGRectMake(0, 320-250, 480, 250);
    }
    [self.view addSubview:pageNav.view];
}

-(void)hidePageNav
{
    if(pageNav != nil) {
        [pageNav.view removeFromSuperview];
        [pageNav release];
        pageNav = nil;
    }
}

-(UIViewController *)popViewControllerAnimated:(BOOL)animated
{
    AwfulAppDelegate *del = (AwfulAppDelegate *)[[UIApplication sharedApplication] delegate];
    [del enableCache];
    [self setToolbarHidden:NO animated:YES];
    [self setNavigationBarHidden:YES animated:YES];
    
    return [super popViewControllerAnimated:animated];
}

-(void)showUnfilteredWithHTML : (NSString *)html
{
    AwfulAppDelegate *del = (AwfulAppDelegate *)[[UIApplication sharedApplication] delegate];
    [del disableCache];
    
    UIWebView *web = [[UIWebView alloc] initWithFrame:CGRectMake(0, 0, 320, 420)];
    web.scalesPageToFit = YES;
    
    [web loadHTMLString:html baseURL:[NSURL URLWithString:@"http://forums.somethingawful.com"]];
    [unfiltered setView:web];
    [web release];
    [self setNavigationBarHidden:NO animated:YES];
    [self pushViewController:unfiltered animated:YES];
}

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    
    if([AwfulConfig allowRotation:interfaceOrientation]) {
        [self setToolbarItems:[self getToolbarItemsForOrientation:interfaceOrientation]];
        return YES;
    }
    
    return NO;
}


- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    [self purge];
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

-(void)purge
{
    if([history count] > 1) {
        id obj = [[history lastObject] retain];
        [history removeAllObjects];
        [history addObject:obj];
        [obj release];
        //[history removeObjectAtIndex:0];
    }
    [self checkHistoryButtons];
}

-(void)callBookmarksRefresh
{
    if(bookmarksRefreshReq != nil) {
        
        bookmarksRefreshReq.threadList.view.userInteractionEnabled = YES;
        [UIView animateWithDuration:0.25 animations:^{
            bookmarksRefreshReq.threadList.view.alpha = 0.3;
        }];
    
        [self loadRequest:bookmarksRefreshReq];
        [bookmarksRefreshReq release];
        bookmarksRefreshReq = nil;
    }
}

#pragma mark MBProgressHUD Delegate
-(void)hudWasHidden : (MBProgressHUD *)hud 
{
    [self.hud removeFromSuperview];
    self.hud = nil;
}

@end

AwfulNavController *getnav()
{
    AwfulAppDelegate *del = (AwfulAppDelegate *)[[UIApplication sharedApplication] delegate];
    return del.navController;
}

int getPostsPerPage()
{
    AwfulNavController *nav = getnav();
    AwfulUser *user = nav.user;
    if(user == nil) {
        return 40;
    }
    return user.postsPerPage;
}

NSString *getUsername()
{
    AwfulNavController *nav = getnav();
    AwfulUser *user = nav.user;
    return [user userName];
}
