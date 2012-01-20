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

@interface AwfulSplitViewController : UISplitViewController <UISplitViewControllerDelegate> {
    UINavigationController *_pageController;
    UINavigationController *_listController;
    UIPopoverController *_popController;
    UIBarButtonItem *_popOverButton;
    BOOL _masterIsVisible;
    CALayer *shadowLayer;
}

@property (nonatomic, retain) UINavigationController *pageController;
@property (nonatomic, retain) UINavigationController *listController;
@property (nonatomic, retain) UIPopoverController *popController;
@property (nonatomic, retain) UIBarButtonItem *popOverButton;
@property (nonatomic, assign) BOOL masterIsVisible;

-(void)showAwfulPage : (AwfulPage *)page;
-(void)showTheadList : (AwfulThreadList *)list;
-(void)addMasterButtonToController: (UIViewController *)vc;
-(void)showMasterView;
-(void)hideMasterView;
@end