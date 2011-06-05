//
//  AwfulAppDelegate.h
//  Awful
//
//  Created by Sean Berry on 7/26/10.
//  Copyright Regular Berry Software LLC 2010. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AwfulNavController.h"
#import "AwfulWebCache.h"
#import "SmilieGrabber.h"
#import "CrashReportSender.h"

@interface AwfulAppDelegate : NSObject <UIApplicationDelegate, UIWebViewDelegate, CrashReportSenderDelegate> {
    UIWindow *window;
    AwfulNavController *navController;
    AwfulWebCache *cache;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet AwfulNavController *navController;

-(void)enableCache;
-(void)disableCache;

@end
