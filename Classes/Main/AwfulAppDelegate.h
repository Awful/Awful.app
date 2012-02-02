//
//  AwfulAppDelegate.h
//  Awful
//
//  Created by Sean Berry on 7/26/10.
//  Copyright Regular Berry Software LLC 2010. All rights reserved.
//

#import <UIKit/UIKit.h>

@class AwfulNavigator;
@class AwfulNavigatorIpad;
@class AwfulSplitViewController;

@interface AwfulAppDelegate : NSObject <UIApplicationDelegate> {
    UIWindow *_window;
    UINavigationController *_navigationController;
    AwfulNavigator *_navigator;

    AwfulSplitViewController *_splitController;
}

@property (nonatomic, strong) IBOutlet UIWindow *window;
@property (nonatomic, strong) IBOutlet UINavigationController *navigationController;
@property (nonatomic, strong) IBOutlet AwfulNavigator *navigator;
@property (nonatomic, strong) IBOutlet AwfulSplitViewController *splitController;

- (void) setupSubview;
- (UIViewController *)getRootController;

@end

@interface AwfulAppDelegateIpad : AwfulAppDelegate
@end;
UIViewController *getRootController();
BOOL isLandscape();