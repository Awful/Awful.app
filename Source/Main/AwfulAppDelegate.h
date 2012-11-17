//
//  AwfulAppDelegate.h
//  Awful
//
//  Created by Sean Berry on 7/26/10.
//  Copyright Regular Berry Software LLC 2010. All rights reserved.
//

#import <UIKit/UIKit.h>

@class AwfulSplitViewController;

@interface AwfulAppDelegate : NSObject <UIApplicationDelegate>

+ (AwfulAppDelegate *)instance;

@property (strong, nonatomic) UIWindow *window;

- (void)logOut;

@end
