//
//  AwfulSplitViewController.m
//  Awful
//
//  Created by Sean Berry on 10/18/11.
//  Copyright (c) 2011 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulSplitViewController.h"

@implementation AwfulSplitViewController

-(void)awakeFromNib
{
    self.delegate = self;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return YES;
}

#pragma mark UISplitViewControllerDelegate

- (void)splitViewController:(UISplitViewController *)svc willHideViewController:(UIViewController *)aViewController withBarButtonItem:(UIBarButtonItem *)barButtonItem forPopoverController:(UIPopoverController *)pc
{
    [barButtonItem setImage:[UIImage imageNamed:@"list_icon.png"]];
    UINavigationController *nav = [self.viewControllers lastObject];
    UIViewController *vc = nav.topViewController;
    vc.navigationItem.leftBarButtonItem = barButtonItem;
}

- (void)splitViewController:(UISplitViewController *)svc willShowViewController:(UIViewController *)aViewController invalidatingBarButtonItem:(UIBarButtonItem *)button
{
    UINavigationController *nav = [self.viewControllers lastObject];
    UIViewController *vc = nav.topViewController;
    vc.navigationItem.leftBarButtonItem = nil;
}

@end
