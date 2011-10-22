//
//  AwfulAppDelegate.m
//  Awful
//
//  Created by Sean Berry on 7/26/10.
//  Copyright Regular Berry Software LLC 2010. All rights reserved.
//

#import "AwfulAppDelegate.h"
#import "AwfulNavigator.h"
#import "FlurryAPI.h"
#import "Appirater.h"
#import "AwfulSplitViewController.h"

@implementation AwfulAppDelegate

@synthesize window = _window;
@synthesize navigationController = _navigationController;
@synthesize navigator = _navigator;
@synthesize navigatorIpad = _navigatorIpad;
@synthesize splitController = _splitController;

#pragma mark -
#pragma mark Application lifecycle

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {    
        
    // Override point for customization after application launch.

    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self.window addSubview:self.splitController.view];
    } else if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        [self.window addSubview:self.navigationController.view];
    }
    [self.window makeKeyAndVisible];
    
    [FlurryAPI startSession:@"EU3TLVQM9U8T8QKNI9ID"];
    
    NSURL *crash_url = [NSURL URLWithString:@"http://www.regularberry.com/crash/crash_v200.php"];
    [[CrashReportSender sharedCrashReportSender] sendCrashReportToURL:crash_url delegate:nil activateFeedback:NO];
    [Appirater appLaunched:YES];
    
    return YES;
}

- (void)dealloc {
    [_splitController release];
    [_navigationController release];
    [_navigator release];
    [_navigatorIpad release];
    [_window release];
    [super dealloc];
}

- (void)applicationWillResignActive:(UIApplication *)application {
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
     If your application supports background execution, called instead of applicationWillTerminate: when the user quits.
     */
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    /*
     Called as part of  transition from the background to the inactive state: here you can undo many of the changes made on entering the background.
     */
    [Appirater appEnteredForeground:YES];
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    AwfulNavigator *nav = getNavigator();
    [nav callBookmarksRefresh];
}


- (void)applicationWillTerminate:(UIApplication *)application {
    /*
     Called when the application is about to terminate.
     See also applicationDidEnterBackground:.
     */
}

#pragma mark -
#pragma mark Memory management

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    /*
     Free up as much memory as possible by purging cached data objects that can be recreated (or reloaded from disk) later.
     */
}

@end

UIViewController *getRootController()
{
    AwfulAppDelegate *del = [[UIApplication sharedApplication] delegate];
    return del.navigationController;
}

