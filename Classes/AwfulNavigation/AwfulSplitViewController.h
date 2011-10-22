//
//  AwfulSplitViewController.h
//  Awful
//
//  Created by Sean Berry on 10/18/11.
//  Copyright (c) 2011 Regular Berry Software LLC. All rights reserved.
//

#import "APSplitViewController.h"

@class AwfulNavigator;
@class AwfulPage;

@interface AwfulSplitViewController : UISplitViewController {
    UINavigationController *_pageController;
    UINavigationController *_listController;
}

@property (nonatomic, retain) UINavigationController *pageController;
@property (nonatomic, retain) UINavigationController *listController;

-(void)showAwfulPage : (AwfulPage *)page;

@end
