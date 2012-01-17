//
//  AwfulSplitViewController.m
//  Awful
//
//  Created by Sean Berry on 10/18/11.
//  Copyright (c) 2011 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulSplitViewController.h"
#import "AwfulForumsList.h"
#import "AwfulThreadList.h"
#import "AwfulPage.h"
#import "AwfulExtrasController.h"
#import "AwfulAppDelegate.h"
#import <QuartzCore/QuartzCore.h>

@implementation AwfulSplitViewController

@synthesize pageController = _pageController;
@synthesize listController = _listController;
@synthesize popController = _popController;
@synthesize popOverButton = _popOverButton;
@synthesize masterIsVisible = _masterIsVisible;

-(id)initWithCoder:(NSCoder *)aDecoder
{
    if((self=[super initWithCoder:aDecoder])) {
        self.delegate = self;
    }
    return self;
}

-(void)dealloc
{
    [_pageController release];
    [_listController release];
    [_popController release];
    [_popOverButton release];
    [super dealloc];
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

/*
 // Implement loadView to create a view hierarchy programmatically, without using a nib.
 - (void)loadView
 {
 }
 */


// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    AwfulForumsListIpad *forums = [[AwfulForumsListIpad alloc] init];
    self.listController = [[[UINavigationController alloc] initWithRootViewController:forums] autorelease];
    [forums release];
    
    AwfulExtrasController *extras = [[AwfulExtrasController alloc] init];
    self.pageController = [[[UINavigationController alloc] initWithRootViewController:extras] autorelease];
    self.pageController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [extras release];
    
    self.viewControllers = [NSArray arrayWithObjects:self.listController, self.pageController, nil];
}


- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    
    self.listController = nil;
    self.pageController = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
	return YES;
}

-(void)showAwfulPage : (AwfulPageIpad *)page
{
    
    self.pageController.viewControllers = [NSArray arrayWithObject:page];
    
    if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation))
    {
        [self hideMasterView];
        [self addMasterButtonToController:page];
    }
}

-(void)showTheadList : (AwfulThreadList *)list
{
    [self showMasterView];
    [self.listController popToRootViewControllerAnimated:NO];
    [self.listController pushViewController:list animated:NO];
    
}

- (void)addBorderToMasterView
{
    UIView *masterView = self.listController.view;
    
    masterView.layer.masksToBounds = NO;
    masterView.layer.borderWidth = 1.0f;
    masterView.layer.cornerRadius = 5.0f;
    
    masterView.layer.backgroundColor = [UIColor blueColor].CGColor;
    masterView.layer.shadowOffset = CGSizeMake(0, 3);
    masterView.layer.shadowRadius = 5.0;
    masterView.layer.shadowColor = [UIColor blackColor].CGColor;
    masterView.layer.shadowOpacity = 0.5;
    
}

- (void)removeBorderToMasterView
{
    UIView *masterView = self.listController.view;
    masterView.layer.masksToBounds = YES;
    masterView.layer.borderWidth = 0.0f;
    masterView.layer.cornerRadius = 0.0f;
    //    masterView.layer.shadowOpacity = 0.0f;
    //    masterView.layer.shadowOffset = CGSizeMake(0, 0);
}
- (void)showMasterView
{
    
    if (!self.masterIsVisible)
    {
        
        self.masterIsVisible = YES;
        
        UIView *masterView = self.listController.view;
        
        CGRect masterFrame = masterView.frame;
        masterFrame.origin.x = 0;
        [self addBorderToMasterView];
        
        [UIView beginAnimations:@"showView" context:NULL];
        masterView.frame = masterFrame;
        [UIView commitAnimations];
        
        self.pageController.view.userInteractionEnabled = NO;
    }
    
}

- (void)hideMasterView
{
    
    if (self.masterIsVisible)
    {
        
        self.masterIsVisible = NO;
        [self removeBorderToMasterView];
        
        UIView *masterView = self.listController.view;
        
        CGRect masterFrame = masterView.frame;
        masterFrame.origin.x = -masterFrame.size.width;
        
        
        [UIView beginAnimations:@"showView" context:NULL];
        masterView.frame = masterFrame;
        [UIView commitAnimations];
        
        
        self.pageController.view.userInteractionEnabled = YES;
        
    }
    
}

-(void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation))
        [self hideMasterView];
}

#pragma mark -
#pragma mark UISplitViewControllerDelegate

/*
 - (BOOL)splitViewController:(UISplitViewController *)svc shouldHideViewController:(UIViewController *)vc inOrientation:(UIInterfaceOrientation)orientation
 {
 return NO;
 }
 */

- (void) addMasterButtonToController:(UIViewController *)vc
{
    self.popOverButton = [[UIBarButtonItem alloc] initWithTitle:@"Threads"
                                                          style:UIBarButtonItemStyleBordered
                                                         target:self
                                                         action:@selector(showMasterView)];
    
    
    UINavigationItem *nav = vc.navigationItem;
    if (nav)
    {
        NSMutableArray *items;
        if (nav.leftBarButtonItems)
        {
            items = [NSMutableArray arrayWithArray:nav.leftBarButtonItems];
            [items insertObject:self.popOverButton atIndex:0];
        }
        else
        {
            items = [NSArray arrayWithObject:self.popOverButton];
        }
        
        [nav setLeftBarButtonItems:items animated:YES];
    }
    self.masterIsVisible = false;
}

- (void)splitViewController:(UISplitViewController *)svc willHideViewController:(UIViewController *)aViewController withBarButtonItem:(UIBarButtonItem *)barButtonItem forPopoverController:(UIPopoverController *)pc
{
    UIViewController *vc = self.pageController.topViewController;
    if ([vc isKindOfClass:[UINavigationController class]])
        [self addMasterButtonToController:[(UINavigationController *)vc topViewController]];
    else
        [self addMasterButtonToController:vc];
}

- (void) splitViewController:(UISplitViewController *)svc willShowViewController:(UIViewController *)aViewController invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem
{
    if (self.popOverButton)
    {
        UINavigationItem *nav = (UINavigationItem *)self.pageController.topViewController.navigationItem;
        
        if (nav.leftBarButtonItems)
        {
            NSMutableArray *items = [NSMutableArray arrayWithArray:nav.leftBarButtonItems];
            [items removeObjectAtIndex:0];
            
            [nav setLeftBarButtonItems:items animated:YES];
        }
        self.popOverButton = nil;
        [self removeBorderToMasterView];
    }
    
    if (self.masterIsVisible)
        self.pageController.view.userInteractionEnabled = YES;
    
    
    self.masterIsVisible = true;
}

@end
