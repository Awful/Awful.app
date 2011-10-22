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

@implementation AwfulSplitViewController

@synthesize pageController = _pageController;
@synthesize listController = _listController;

-(void)dealloc
{
    [_pageController release];
    [_listController release];
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

-(void)showAwfulPage : (AwfulPage *)page
{
    self.pageController.viewControllers = [NSArray arrayWithObject:page];
}

@end
