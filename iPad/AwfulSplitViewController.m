//
//  AwfulSplitViewController.m
//  Awful
//
//  Created by Sean Berry on 10/18/11.
//  Copyright (c) 2011 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulSplitViewController.h"
#import "AwfulLoginController.h"

@implementation AwfulSplitViewController
@synthesize popoverController, rootPopoverButtonItem;

-(void)awakeFromNib
{
    self.delegate = self;
    
    UITabBarController *tbc =  [self.viewControllers objectAtIndex:0];
    if (!IsLoggedIn()) {
        tbc.selectedIndex = 3;
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return YES;
}
#pragma mark - UISplitViewControllerDelegate

- (void)splitViewController:(UISplitViewController*)svc willHideViewController:(UIViewController *)aViewController withBarButtonItem:(UIBarButtonItem*)barButtonItem forPopoverController:(UIPopoverController*)pc {
    
        // Keep references to the popover controller and the popover button, and tell the detail view controller to show the button.
    [barButtonItem setImage:[UIImage imageNamed:@"list_icon.png"]];
    self.popoverController = pc;
    self.rootPopoverButtonItem = barButtonItem;
    UIViewController <SubstitutableDetailViewController> *detailViewController = (UIViewController<SubstitutableDetailViewController>*)[[self.viewControllers objectAtIndex:1] topViewController];
    [detailViewController showRootPopoverButtonItem:rootPopoverButtonItem];
}


- (void)splitViewController:(UISplitViewController*)svc willShowViewController:(UIViewController *)aViewController invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem {
    
        // Nil out references to the popover controller and the popover button, and tell the detail view controller to hide the button.
    UIViewController <SubstitutableDetailViewController> *detailViewController = (UIViewController<SubstitutableDetailViewController>*)[[self.viewControllers objectAtIndex:1] topViewController];
    [detailViewController invalidateRootPopoverButtonItem:rootPopoverButtonItem];
    self.popoverController = nil;
    self.rootPopoverButtonItem = nil;
}

-(void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if (rootPopoverButtonItem != nil) {
        UIViewController<SubstitutableDetailViewController>* detailViewController = (UIViewController<SubstitutableDetailViewController>*)[segue.destinationViewController topViewController];
        [detailViewController showRootPopoverButtonItem:self.rootPopoverButtonItem];
    }
    
    if (popoverController != nil) {
        [popoverController dismissPopoverAnimated:YES];
    }
}
@end
