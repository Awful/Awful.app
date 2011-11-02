//
//  AwfulSplitViewController.h
//  Awful
//
//  Created by Sean Berry on 10/18/11.
//  Copyright (c) 2011 Regular Berry Software LLC. All rights reserved.
//

@class AwfulNavigator;
@class AwfulPage;

@interface AwfulSplitViewController : UISplitViewController <UISplitViewControllerDelegate> {
    UINavigationController *_pageController;
    UINavigationController *_listController;
    UIPopoverController *_popController;
    UIBarButtonItem *_popOverButton;
}

@property (nonatomic, retain) UINavigationController *pageController;
@property (nonatomic, retain) UINavigationController *listController;
@property (nonatomic, retain) UIPopoverController *popController;
@property (nonatomic, retain) UIBarButtonItem *popOverButton;

-(void)showAwfulPage : (AwfulPage *)page;

@end