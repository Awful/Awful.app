//
//  AwfulSplitViewController.h
//  Awful
//
//  Created by Sean Berry on 10/18/11.
//  Copyright (c) 2011 Regular Berry Software LLC. All rights reserved.
//

@class AwfulNavigator;
@class AwfulPage;
@class AwfulThreadList;
@class AwfulIpadMasterController;

@interface AwfulSplitViewController : UISplitViewController <UISplitViewControllerDelegate, UITabBarControllerDelegate> {
    UINavigationController *_pageController;
    UINavigationController *_listController;
    UITabBarController *_masterController;
    UIPopoverController *_popController;
    UIBarButtonItem *_popOverButton;
    BOOL _masterIsVisible;
    CALayer *shadowLayer;
}

@property (nonatomic, retain) IBOutlet UINavigationController *pageController;
@property (nonatomic, retain) IBOutlet UINavigationController *listController;
@property (nonatomic, retain) IBOutlet UITabBarController *masterController;
@property (nonatomic, retain) UIPopoverController *popController;
@property (nonatomic, retain) UIBarButtonItem *popOverButton;
@property (nonatomic, assign) BOOL masterIsVisible;

-(void)showAwfulPage : (AwfulPage *)page;
-(void)showTheadList : (AwfulThreadList *)list;
-(void)addMasterButtonToController: (UIViewController *)vc;
-(void)showMasterView;
-(void)hideMasterView;
@end