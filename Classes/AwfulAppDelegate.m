//
//  AwfulAppDelegate.m
//  Awful
//
//  Created by Sean Berry on 7/26/10.
//  Copyright Regular Berry Software LLC 2010. All rights reserved.
//

#import "AwfulAppDelegate.h"
#import "AwfulUtil.h"
#import "BookmarksController.h"
#import "TFHpple.h"
#import "FlurryAPI.h"
#import "AwfulThreadList.h"
#import "AwfulPage.h"
#import "AwfulForumsList.h"
#import "Appirater.h"
#import "AwfulConfig.h"

@implementation AwfulAppDelegate

@synthesize window;
@synthesize navController;


#pragma mark -
#pragma mark Application lifecycle

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {    
        
    // Override point for customization after application launch.

    cache = nil;
    
    [AwfulUtil initializeDatabase];
            
    // Add the tab bar controller's view to the window and display.
    [window addSubview:navController.view];
    [window makeKeyAndVisible];

    [self enableCache];
    
    [FlurryAPI startSession:@"EU3TLVQM9U8T8QKNI9ID"];
    
    // I don't want to see your crash reports!
    NSURL *crash_url = [NSURL URLWithString:@"http://www.regularberry.com/crash/crash_v200.php"];
    [[CrashReportSender sharedCrashReportSender] sendCrashReportToURL:crash_url delegate:self activateFeedback:NO];
    //[Appirater appLaunched:YES];
    
    /*if([AwfulConfig isColorSchemeBlack]) {
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque];
    } else {
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault];
    }*/
    
    return YES;
}

- (void)dealloc {
    [cache release];
    [navController release];
    [window release];
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
    //[Appirater appEnteredForeground:YES];
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
     if([navController.modalViewController isMemberOfClass:[UINavigationController class]]) {
        UINavigationController *nav = (UINavigationController *)navController.modalViewController;
        if([nav.topViewController isMemberOfClass:[BookmarksController class]]) {
            BookmarksController *book = (BookmarksController *)nav.topViewController;
            [book refresh];
        }
     }
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

-(void)enableCache
{
    if(cache == nil) {
        NSString *path = [[NSBundle mainBundle] pathForResource:@"awfulcache" ofType:nil];
        cache = [[AwfulWebCache alloc] initWithMemoryCapacity:512*1024 diskCapacity:10*1024*1024 diskPath:path];
    }
    //NSLog(@"cache enabled");
    
    [NSURLCache setSharedURLCache:cache];
}

-(void)disableCache
{
    //NSLog(@"cache disabled");
    [NSURLCache setSharedURLCache:nil];
}

@end

