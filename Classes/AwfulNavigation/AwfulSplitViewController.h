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

@property (nonatomic, strong) IBOutlet UINavigationController *pageController;
@property (nonatomic, strong) IBOutlet UINavigationController *listController;
@property (nonatomic, strong) IBOutlet UITabBarController *masterController;
@property (nonatomic, strong) UIPopoverController *popController;
@property (nonatomic, strong) UIBarButtonItem *popOverButton;
@property (nonatomic, assign) BOOL masterIsVisible;

-(void)setupMasterView;
-(void)showAwfulPage : (AwfulPage *)page;
-(void)showTheadList : (AwfulThreadList *)list;
-(void)addMasterButtonToController: (UIViewController *)vc;
-(void)showMasterView;
-(void)hideMasterView;
-(void) showLoginView;
@end