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
#import "AwfulPageNavController.h"

@implementation AwfulNavigator

@synthesize toolbar = _toolbar;
@synthesize contentVC = _contentVC;
@synthesize requestHandler = _requestHandler;
@synthesize user = _user;
@synthesize actions = _actions;
@synthesize pageNav = _pageNav;

-(id)initWithCoder:(NSCoder *)aDecoder
{
    if((self = [super initWithCoder:aDecoder])) {
        _requestHandler = [[AwfulRequestHandler alloc] init];
        _contentVC = nil;
        _actions = nil;
        _pageNav = nil;
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
    [_pageNav release];
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
/*
-(void)setPageNav:(AwfulPageNavController *)pageNav
{
    if(_pageNav != pageNav) {
        [_pageNav.view removeFromSuperview];
        [_pageNav release];
        _pageNav = [pageNav retain];
        
        if(_pageNav != nil) {
            
        }
    }
}*/

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UIBarButtonItem *refresh = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refresh)];
    self.navigationItem.leftBarButtonItem = refresh;
    [refresh release];
    
    [self setToolbarItems:[self.toolbar items] animated:YES];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    self.toolbar = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return YES;
    //return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Toolbar Items

-(void)refresh
{
    [self swapToStopButton];
    [self.contentVC refresh];
}

-(void)stop
{
    [self swapToRefreshButton];
    [self.contentVC stop];
}

-(void)swapToRefreshButton
{
    UIBarButtonItem *refresh = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refresh)];
    self.navigationItem.leftBarButtonItem = refresh;
    [refresh release];
}

-(void)swapToStopButton
{
    UIBarButtonItem *stop = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(stop)];
    self.navigationItem.leftBarButtonItem = stop;
    [stop release];
}

-(IBAction)tappedBack
{
    
}

-(IBAction)tappedForumsList
{
    AwfulForumsList *forums = [[AwfulForumsList alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:forums];
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
    
}

#pragma mark Awful Content Navigation

-(void)loadContentVC : (id<AwfulNavigatorContent>)content
{
    [self dismissModalViewControllerAnimated:YES];
    
    self.contentVC = content;
    [self.contentVC setDelegate:self];
    
    self.view = [self.contentVC getView];
    [self.contentVC refresh];
}

#pragma mark Gestures

-(void)tappedThreeTimes : (UITapGestureRecognizer *)gesture
{
    if([self.navigationController isToolbarHidden]) {
        [self.navigationController setToolbarHidden:NO animated:YES];
        [self.navigationController setNavigationBarHidden:NO animated:NO];
    } else {
        [self.navigationController setToolbarHidden:YES animated:YES];
        [self.navigationController setNavigationBarHidden:YES animated:YES];
    }
}

#pragma Navigation Controller Delegate
- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    if(viewController == self) {
        self.view = [self.contentVC getView];
    }
}

#pragma mark Gesture Delegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

@end

AwfulNavigator *getNavigator()
{
    AwfulAppDelegate *del = (AwfulAppDelegate *)[[UIApplication sharedApplication] delegate];
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
