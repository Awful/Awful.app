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

@end


@implementation AwfulSplitViewController

- (id)init
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.delegate = self;
    }
    return self;
}

- (void)ensureLeftBarButtonItemOnDetailView
{
    if (!self.rootPopoverButtonItem) return;
    UINavigationController *nav = self.viewControllers[1];
    UIViewController *detail = nav.viewControllers[0];
    if ([detail.navigationItem.leftBarButtonItem isEqual:self.rootPopoverButtonItem]) return;
    self.rootPopoverButtonItem.accessibilityLabel = @"Sidebar";
    [detail.navigationItem setLeftBarButtonItem:self.rootPopoverButtonItem animated:YES];
}

- (void)showMasterView
{
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self.rootPopoverButtonItem.target performSelector:self.rootPopoverButtonItem.action
                                            withObject:self.rootPopoverButtonItem];
    #pragma clang diagnostic pop
}

#pragma mark - UIViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    return [self init];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

#pragma mark - UISplitViewControllerDelegate

- (BOOL)splitViewController:(UISplitViewController *)svc
   shouldHideViewController:(UIViewController *)vc
              inOrientation:(UIInterfaceOrientation)orientation
{
    return YES;
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

@end
