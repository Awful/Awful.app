//
//  AwfulAppDelegate.h
//  Awful
//
//  Created by Sean Berry on 7/26/10.
//  Copyright Regular Berry Software LLC 2010. All rights reserved.
//

#import <UIKit/UIKit.h>

@class AwfulSplitViewController;
@class AwfulNetworkEngine;

#define ApplicationDelegate ((AwfulAppDelegate *)[UIApplication sharedApplication].delegate)

@interface AwfulAppDelegate : NSObject <UIApplicationDelegate>

@property (nonatomic, strong) IBOutlet UIWindow *window;
@property (nonatomic, strong) IBOutlet AwfulSplitViewController *splitController;
@property (nonatomic, strong) AwfulNetworkEngine *awfulNetworkEngine;

-(UIViewController *)getRootController;
-(void)initializeiCloudAccess;
-(void)iCloudKeyChanged : (NSNotification *)aNotification;

@end

BOOL isLandscape();