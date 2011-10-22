//
//  AwfulNavigator.m
//  Awful
//
//  Created by Regular Berry on 6/21/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulNavigator.h"
#import "AwfulLoginController.h"
#import "AwfulExtrasController.h"
#import "AwfulAppDelegate.h"
#import "AwfulForumsList.h"
#import "AwfulRequestHandler.h"
#import "AwfulPageCount.h"
#import "AwfulBookmarksController.h"
#import "AwfulUser.h"
#import "AwfulActions.h"
#import "AwfulConfig.h"
#import "AwfulHistoryManager.h"
#import "AwfulSplitViewController.h"

@implementation AwfulNavigator

@synthesize toolbar = _toolbar;
@synthesize contentVC = _contentVC;
@synthesize requestHandler = _requestHandler;
@synthesize user = _user;
@synthesize actions = _actions;
@synthesize historyManager = _historyManager;
@synthesize backButton = _backButton;
@synthesize forwardButton = _forwardButton;
@synthesize actionButton = _actionButton;
@synthesize welcomeMessage = _welcomeMessage;
@synthesize fullScreenButton = _fullScreenButton;

-(id)initWithCoder:(NSCoder *)aDecoder
{
    if((self = [super initWithCoder:aDecoder])) {
        _requestHandler = [[AwfulRequestHandler alloc] init];
        _contentVC = nil;
        _actions = nil;
        _historyManager = [[AwfulHistoryManager alloc] init];
        _user = [[AwfulUser alloc] init];
        [_user loadUser];
    }
    return self;
}

- (void)dealloc
{
    [_toolbar release];
    [_contentVC release];
    [_requestHandler release];
    [_user release];
    [_actions release];
    [_historyManager release];
    [_backButton release];
    [_forwardButton release];
    [_actionButton release];
    [_fullScreenButton release];
    [super dealloc];
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

-(void)setActions:(AwfulActions *)actions
{
    if(actions != _actions) {
        [_actions release];
        _actions = [actions retain];
        _actions.delegate = self;
        [_actions show];
    }
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.fullScreenButton removeFromSuperview];
    
    [self updateHistoryButtons];
    [self swapToRefreshButton];
    
    [self setToolbarItems:[self.toolbar items] animated:YES];
    
    if(isLoggedIn()) {
        self.welcomeMessage.text = @"";
        AwfulDefaultLoadType load_type = [AwfulConfig getDefaultLoadType];
        if(load_type == AwfulDefaultLoadTypeBookmarks) {
            [self tappedBookmarks];
        } else if(load_type == AwfulDefaultLoadTypeForums) {
            [self tappedForumsList];
        }
    } else {
        self.welcomeMessage.text = @"Tap '...' below to log in.";
        [self tappedMore];
    }
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    self.toolbar = nil;
    self.backButton = nil;
    self.forwardButton = nil;
    self.actionButton = nil;
    self.welcomeMessage = nil;
    self.fullScreenButton = nil;
}

-(void)viewWillAppear:(BOOL)animated
{
    if(isLoggedIn()) {
        self.welcomeMessage.text = @"";
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

#pragma mark - Toolbar Items

-(void)refresh
{
    [self swapToStopButton];
    
    if([self.contentVC isMemberOfClass:[AwfulPage class]]) {
        AwfulPage *page = (AwfulPage *)self.contentVC;
        [page hardRefresh];
    } else {
        [self.contentVC refresh];
    }
}

-(void)stop
{
    [self swapToRefreshButton];
    [self.contentVC stop];
}

-(void)swapToRefreshButton
{
    // check if already display 'refresh', prevents a crash when multiple threads are telling it to go to 'refresh'
    if(self.navigationItem.leftBarButtonItem.action != @selector(refresh)) {
        UIBarButtonItem *refresh = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refresh)];
        self.navigationItem.leftBarButtonItem = refresh;
        [refresh release];
    }
}

-(void)swapToStopButton
{
    if(self.navigationItem.leftBarButtonItem.action != @selector(stop)) {
        UIBarButtonItem *stop = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(stop)];
        self.navigationItem.leftBarButtonItem = stop;
        [stop release];
    }
}

-(void)updateHistoryButtons
{
    self.backButton.enabled = [self.historyManager isBackEnabled];
    self.forwardButton.enabled = [self.historyManager isForwardEnabled];
    
    if(self.contentVC == nil) {
        self.actionButton.enabled = NO;
    }
}

-(IBAction)tappedBack
{
    [self.historyManager goBack];
    [self updateHistoryButtons];
}

-(IBAction)tappedForward
{
    [self.historyManager goForward];
    [self updateHistoryButtons];
}

-(IBAction)tappedForumsList
{
    AwfulForumsList *forums = [[AwfulForumsList alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:forums];
    nav.navigationBar.barStyle = UIBarStyleBlackOpaque;
    [self presentModalViewController:nav animated:YES];
    [nav release];
    [forums release];
}

-(IBAction)tappedAction
{
    AwfulActions *actions = [self.contentVC getActions];
    if(actions != nil) {
        [self setActions:actions];
    }
}

-(IBAction)tappedBookmarks
{
    AwfulBookmarksController *books = [[AwfulBookmarksController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:books];
    nav.navigationBar.barStyle = UIBarStyleBlackOpaque;
    
    [self presentModalViewController:nav animated:YES];
    [nav release];
    [books release];
}

-(IBAction)tappedMore
{
    AwfulExtrasController *extras = [[AwfulExtrasController alloc] init];
    [self.navigationController pushViewController:extras animated:YES];
    [extras release];
}

-(void)callBookmarksRefresh
{
    if(self.modalViewController != nil) {
        if([self.modalViewController isKindOfClass:[UINavigationController class]]) {
            UINavigationController *nav = (UINavigationController *)self.modalViewController;
            if([nav.visibleViewController isMemberOfClass:[AwfulBookmarksController class]]) {
                AwfulBookmarksController *book = (AwfulBookmarksController *)nav.visibleViewController;
                [book refresh];
            }
        }
    }
}

#pragma mark Awful Content Navigation

-(void)loadContentVC : (id<AwfulNavigatorContent>)content
{
    [self dismissModalViewControllerAnimated:YES];
    
    [self.historyManager addHistory:content];
    [self updateHistoryButtons];
    
    self.contentVC = content;
    [self.contentVC setDelegate:self];
    
    self.view = [self.contentVC getView];
    if([self isFullscreen]) {
        self.fullScreenButton.center = CGPointMake(self.view.frame.size.width-25, self.view.frame.size.height-25);
        [self.view addSubview:self.fullScreenButton];
    }
    [self.contentVC refresh];
    
    AwfulActions *actions = [self.contentVC getActions];
    if(actions == nil) {
        self.actionButton.enabled = NO;
    } else {
        self.actionButton.enabled = YES;
    }
}

#pragma mark Gestures

-(void)didFullscreenGesture : (UIGestureRecognizer *)gesture
{
    if([gesture isMemberOfClass:[UIPinchGestureRecognizer class]]) {
        if([gesture state] != UIGestureRecognizerStateBegan) {
            return;
        }
    }
    
    if([self isFullscreen]) {
        [self.navigationController setToolbarHidden:NO animated:YES];
        [self.navigationController setNavigationBarHidden:NO animated:YES];
        [self.fullScreenButton removeFromSuperview];
    } else {
        [self.navigationController setToolbarHidden:YES animated:YES];
        [self.navigationController setNavigationBarHidden:YES animated:YES];
        self.fullScreenButton.center = CGPointMake(self.view.frame.size.width-25, self.view.frame.size.height-25);
        [self.view addSubview:self.fullScreenButton];
    }
}

-(IBAction)tappedFullscreen : (id)sender
{
    [self didFullscreenGesture:nil];
}

-(BOOL)isFullscreen
{
    return [self.navigationController isToolbarHidden];
}

-(void)forceShow
{
    [self.navigationController setToolbarHidden:NO animated:YES];
    [self.navigationController setNavigationBarHidden:NO animated:YES];
}

#pragma Navigation Controller Delegate
- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    if(viewController == self && self.contentVC != nil) {
        if([self.navigationController.viewControllers count] == 1) {
            self.view = [self.contentVC getView];
        }
    }
}

#pragma mark Gesture Delegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

@end

@implementation AwfulNavigatorIpad

-(void)loadContentVC : (id<AwfulNavigatorContent>)content
{
    [self dismissModalViewControllerAnimated:YES];
    
    if([content isMemberOfClass:[AwfulPage class]]) {
        AwfulAppDelegate *del = (AwfulAppDelegate *)[[UIApplication sharedApplication] delegate];
        [del.splitController showAwfulPage:(AwfulPage *)content];
    }
    
    self.contentVC = content;
    [self.contentVC setDelegate:self];
    [self.contentVC refresh];
}

-(void)setActions:(AwfulActions *)actions
{
    
}

@end

AwfulNavigator *getNavigator()
{
    AwfulAppDelegate *del = (AwfulAppDelegate *)[[UIApplication sharedApplication] delegate];
    
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return del.navigatorIpad;
    }
    
    return del.navigator;
}

void loadContentVC(id<AwfulNavigatorContent> content)
{
    AwfulNavigator *nav = getNavigator();
    [nav loadContentVC:content];
}

void loadRequest(ASIHTTPRequest *req)
{
    AwfulNavigator *nav = getNavigator();
    [nav.requestHandler loadRequest:req];
}
     
void loadRequestAndWait(ASIHTTPRequest *req)
{
    AwfulNavigator *nav = getNavigator();
    [nav.requestHandler loadRequestAndWait:req];
}
