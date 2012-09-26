//
//  AwfulSplitViewController.m
//  Awful
//
//  Created by Sean Berry on 10/18/11.
//  Copyright (c) 2011 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulSplitViewController.h"
#import "AwfulLoginController.h"
#import "AwfulSettings.h"

@implementation AwfulSplitViewController

- (void)awakeFromNib
{
    [super awakeFromNib];
    self.delegate = self;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

#pragma mark - Split view controller delegate

- (void)splitViewController:(UISplitViewController*)svc
     willHideViewController:(UIViewController *)aViewController
          withBarButtonItem:(UIBarButtonItem*)barButtonItem
       forPopoverController:(UIPopoverController*)pc
{
    // Keep references to the popover controller and the popover button, and tell the detail view controller to show the button.
    [barButtonItem setImage:[UIImage imageNamed:@"list_icon.png"]];
    self.masterPopoverController = pc;
    self.rootPopoverButtonItem = barButtonItem;
    UIViewController <SubstitutableDetailViewController> *detailViewController = (UIViewController<SubstitutableDetailViewController>*)[[self.viewControllers objectAtIndex:1] topViewController];
    [detailViewController showRootPopoverButtonItem:self.rootPopoverButtonItem];
}


- (void)splitViewController:(UISplitViewController*)svc
     willShowViewController:(UIViewController *)aViewController
  invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem
{
    // Nil out references to the popover controller and the popover button, and tell the detail view controller to hide the button.
    UIViewController <SubstitutableDetailViewController> *detailViewController = (UIViewController<SubstitutableDetailViewController>*)[[self.viewControllers objectAtIndex:1] topViewController];
    [detailViewController invalidateRootPopoverButtonItem:self.rootPopoverButtonItem];
    self.masterPopoverController = nil;
    self.rootPopoverButtonItem = nil;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if (self.rootPopoverButtonItem) {
        UIViewController<SubstitutableDetailViewController>* detailViewController = (UIViewController<SubstitutableDetailViewController>*)[segue.destinationViewController topViewController];
        [detailViewController showRootPopoverButtonItem:self.rootPopoverButtonItem];
    }
    
    if (self.masterPopoverController) {
        [self.masterPopoverController dismissPopoverAnimated:YES];
    }
}
@end
