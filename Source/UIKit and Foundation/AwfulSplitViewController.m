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

@interface AwfulSplitViewController () <UISplitViewControllerDelegate>

@property (readonly, getter=isMasterViewVisible, nonatomic) BOOL masterViewVisible;

@end


@implementation AwfulSplitViewController

// If you're hiding the master view in both orientations, and you set the delegate before setting
// the view controllers, you get a spurious warning. So we set the delegate here instead.
- (void)setViewControllers:(NSArray *)viewControllers
{
    [super setViewControllers:viewControllers];
    self.delegate = self;
}

- (void)ensureLeftBarButtonItemOnDetailView
{
    if (!self.rootPopoverButtonItem) return;
    if ([self.viewControllers count] < 2) return;
    UINavigationController *nav = self.viewControllers[1];
    UIViewController *detail = nav.viewControllers[0];
    if ([detail.navigationItem.leftBarButtonItem isEqual:self.rootPopoverButtonItem]) return;
    self.rootPopoverButtonItem.accessibilityLabel = @"Sidebar";
    [detail.navigationItem setLeftBarButtonItem:self.rootPopoverButtonItem animated:YES];
}

- (void)showMasterView
{
    if (self.masterViewVisible) return;
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self.rootPopoverButtonItem.target performSelector:self.rootPopoverButtonItem.action
                                            withObject:self.rootPopoverButtonItem];
    #pragma clang diagnostic pop
}

- (BOOL)isMasterViewVisible
{
    return !self.masterPopoverController;
}

#pragma mark - UIViewController

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

#pragma mark - UISplitViewControllerDelegate

- (BOOL)splitViewController:(UISplitViewController *)svc
   shouldHideViewController:(UIViewController *)vc
              inOrientation:(UIInterfaceOrientation)orientation
{
    switch ([AwfulSettings settings].keepSidebarOpen) {
        case AwfulKeepSidebarOpenAlways: return NO;
        case AwfulKeepSidebarOpenInLandscape: return UIInterfaceOrientationIsPortrait(orientation);
        case AwfulKeepSidebarOpenInPortrait: return UIInterfaceOrientationIsLandscape(orientation);
        case AwfulKeepSidebarOpenNever: default: return YES;
    }
}

- (void)splitViewController:(UISplitViewController*)svc
     willHideViewController:(UIViewController *)aViewController
          withBarButtonItem:(UIBarButtonItem*)barButtonItem
       forPopoverController:(UIPopoverController*)pc
{
    [barButtonItem setImage:[UIImage imageNamed:@"list_icon.png"]];
    self.masterPopoverController = pc;
    self.rootPopoverButtonItem = barButtonItem;
    [self ensureLeftBarButtonItemOnDetailView];
}


- (void)splitViewController:(UISplitViewController*)svc
     willShowViewController:(UIViewController *)aViewController
  invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem
{
    UINavigationController *nav = self.viewControllers[1];
    UIViewController *detail = nav.viewControllers[0];
    if ([detail.navigationItem.leftBarButtonItem isEqual:self.rootPopoverButtonItem]) {
        [detail.navigationItem setLeftBarButtonItem:nil animated:YES];
    }
    self.masterPopoverController = nil;
    self.rootPopoverButtonItem = nil;
}

- (void)splitViewController:(UISplitViewController *)svc
          popoverController:(UIPopoverController *)pc
  willPresentViewController:(UIViewController *)aViewController
{
    // There's a bug in iOS 5.1, fixed in iOS 6, in UISplitViewController: if the master view is
    // hidden when a memory warning occurs, it loses its frame. The next time it's shown, it takes
    // on a frame whose width seems to be the device's portrait width. Here we fix that.
    CGRect frame = aViewController.view.frame;
    frame.size.width = 320;
    aViewController.view.frame = frame;
}

@end
