//
//  AwfulSplitViewController.h
//  Awful
//
//  Created by Nolan Waite on 2013-04-15.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

#import <UIKit/UIKit.h>
@protocol AwfulSplitViewControllerDelegate;

// Basically UISplitViewController.
@interface AwfulSplitViewController : UIViewController

// Designated initializer.
- (instancetype)initWithSidebarViewController:(UIViewController *)sidebarViewController
                           mainViewController:(UIViewController *)mainViewController;

@property (weak, nonatomic) id <AwfulSplitViewControllerDelegate> delegate;

// The sidebarViewController is on the left.
@property (readonly, nonatomic) UIViewController *sidebarViewController;

// The main view controller is on the right.
@property (readonly, nonatomic) UIViewController *mainViewController;

// An array of the sidebar view controller and the main view controller. Exists for
// -[AwfulTheming recursivelyRetheme].
@property (readonly, nonatomic) NSArray *viewControllers;

// Show or hide the sidebar. If the sidebar cannot hide in the current interface orientation,
// setting this property does nothing.
@property (getter=isSidebarVisible, nonatomic) BOOL sidebarVisible;
- (void)setSidebarVisible:(BOOL)sidebarVisible animated:(BOOL)animated;

// Allow or disallow the sidebar to hide. If the sidebar is currently visible, it remains visible.
// This method sends no message to the delegate.
@property (nonatomic) BOOL sidebarCanHide;

@end


@protocol AwfulSplitViewControllerDelegate <NSObject>

// Sent when the splitViewController is first shown and subsequently when the interface orientation
// changes.
- (BOOL)awfulSplitViewController:(AwfulSplitViewController *)controller
  shouldHideSidebarInOrientation:(UIInterfaceOrientation)orientation;

// Sent during an interface orientation change if the sidebar's ability to hide changes. This is a
// good time to add or remove a bar button item to the mainViewController's navigationItem.
- (void)awfulSplitViewController:(AwfulSplitViewController *)controller
                 willHideSidebar:(BOOL)willHideSidebar;

@end


@interface UIViewController (AwfulSplitViewController)

// Returns nil if this view controller is not contained in an AwfulSplitViewController.
@property (readonly, nonatomic) AwfulSplitViewController *awfulSplitViewController;

@end
