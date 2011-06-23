//
//  AwfulAppDelegate.h
//  Awful
//
//  Created by Sean Berry on 7/26/10.
//  Copyright Regular Berry Software LLC 2010. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CrashReportSender.h"
#import "AwfulNavController.h"

@class AwfulNavigator;

@interface AwfulAppDelegate : NSObject <UIApplicationDelegate, UIWebViewDelegate, CrashReportSenderDelegate> {
    UIWindow *_window;
    UINavigationController *_navigationController;
    AwfulNavigator *_navigator;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet UINavigationController *navigationController;
@property (nonatomic, retain) IBOutlet AwfulNavigator *navigator;

@end

UIViewController *getRootController();