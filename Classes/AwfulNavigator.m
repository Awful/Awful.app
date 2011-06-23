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
#import "AwfulTableViewController.h"
#import "AwfulBookmarksController.h"
#import "AwfulUser.h"
#import "AwfulTestPage.h"

@implementation AwfulNavigator

@synthesize toolbar = _toolbar;
@synthesize contentVC = _contentVC;
@synthesize requestHandler = _requestHandler;
@synthesize user = _user;

-(id)initWithCoder:(NSCoder *)aDecoder
{
    if((self = [super initWithCoder:aDecoder])) {
        _requestHandler = [[AwfulRequestHandler alloc] init];
        _contentVC = nil;
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
    [super dealloc];
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self setToolbarItems:[self.toolbar items] animated:YES];
    
    AwfulTestPage *test = [[AwfulTestPage alloc] initWithNibName:nil bundle:nil];
    [test refresh];
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

-(void)loadContentVC : (AwfulTableViewController *)content
{
    [self dismissModalViewControllerAnimated:YES];
    
    self.contentVC = content;
    [self.contentVC setDelegate:self];
    
    self.view = self.contentVC.view;
    [self.contentVC refresh];
    
    UITapGestureRecognizer *gest = [[UITapGestureRecognizer alloc] 
                                    initWithTarget:self 
                                    action:@selector(tappedThreeTimes:)];
    gest.numberOfTapsRequired = 3;
    [self.view addGestureRecognizer:gest];
    [gest release];
}

-(void)loadOtherView : (UIView *)other_view
{
    [self dismissModalViewControllerAnimated:YES];
    self.view = other_view;
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

@end

AwfulNavigator *getNavigator()
{
    AwfulAppDelegate *del = (AwfulAppDelegate *)[[UIApplication sharedApplication] delegate];
    return del.navigator;
}

void loadContentVC(AwfulTableViewController *content)
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
