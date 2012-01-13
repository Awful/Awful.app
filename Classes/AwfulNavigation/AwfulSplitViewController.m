//
//  AwfulSplitViewController.m
//  Awful
//
//  Created by Sean Berry on 10/18/11.
//  Copyright (c) 2011 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulSplitViewController.h"
#import "AwfulForumsList.h"
#import "AwfulPage.h"
#import "AwfulExtrasController.h"
#import "AwfulAppDelegate.h"

@implementation AwfulSplitViewController

@synthesize pageController = _pageController;
@synthesize listController = _listController;
@synthesize popController = _popController;
@synthesize popOverButton = _popOverButton;

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
    if (self.popController)
        [self.popController dismissPopoverAnimated:YES];
    
    self.pageController.viewControllers = [NSArray arrayWithObject:page];
}

#pragma mark -
#pragma mark UISplitViewControllerDelegate

/*
 - (BOOL)splitViewController:(UISplitViewController *)svc shouldHideViewController:(UIViewController *)vc inOrientation:(UIInterfaceOrientation)orientation
 {
 return NO;
 }
 */

- (void)splitViewController:(UISplitViewController *)svc willHideViewController:(UIViewController *)aViewController withBarButtonItem:(UIBarButtonItem *)barButtonItem forPopoverController:(UIPopoverController *)pc
{
    self.popController = pc;
    //    pc.delegate = self;
    barButtonItem.title = @"Threads";
    self.popOverButton = barButtonItem;
    
    UINavigationItem *nav = (UINavigationItem *)self.pageController.topViewController.navigationItem;
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
}

- (void) splitViewController:(UISplitViewController *)svc willShowViewController:(UIViewController *)aViewController invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem
{
    if (self.popOverButton)
    {
        UINavigationItem *nav = (UINavigationItem *)self.pageController.topViewController.navigationItem;
        
        NSMutableArray *items = [NSMutableArray arrayWithObject:nav.leftBarButtonItems];
        [items removeObjectAtIndex:0];

            [nav setLeftBarButtonItems:items animated:YES];
        
        self.popOverButton = nil;
    }
}

@end
