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
#import "AwfulNetworkEngine.h"
#import "AwfulTabBarController.h"

@implementation AwfulAppDelegate

@synthesize window = _window;
@synthesize navigationController = _navigationController;
@synthesize navigator = _navigator;
@synthesize splitController = _splitController;
@synthesize awfulNetworkEngine = _awfulNetworkEngine;

#pragma mark -
#pragma mark Application lifecycle

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {    
        
    // Override point for customization after application launch.
    
    self.awfulNetworkEngine = [[AwfulNetworkEngine alloc] initWithHostName:@"forums.somethingawful.com" customHeaderFields:nil];
    
    [self.window makeKeyAndVisible];
    
    [FlurryAPI startSession:@"EU3TLVQM9U8T8QKNI9ID"];
    
    [Appirater appLaunched:YES];
    //[self initializeiCloudAccess];
    
    return YES;
}

- (void)initializeiCloudAccess {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if ([[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil] != nil) {            
            NSUbiquitousKeyValueStore *store = [NSUbiquitousKeyValueStore defaultStore];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(iCloudKeyChanged:) name:NSUbiquitousKeyValueStoreDidChangeExternallyNotification object:store];
            [store synchronize];
        } else {
            //UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"iCloud Not Enabled" message:@"You won't be able to use custom stylesheets." delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
            //[alert show];
        }
    });
}

-(void)iCloudKeyChanged : (NSNotification *)aNotification
{
    NSDictionary *userInfo = [aNotification userInfo];
    NSNumber *reason = [userInfo objectForKey:NSUbiquitousKeyValueStoreChangeReasonKey];
    if(!reason) {
        return;
    }
    
    NSInteger reason_value = [reason integerValue];
    if(reason_value == NSUbiquitousKeyValueStoreServerChange) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Template Loaded" message:@"Got new template from iCloud" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
        [alert show];
    }
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
    if ([nav isKindOfClass:[AwfulNavigatorIpad class]])
        [((AwfulNavigatorIpad *) nav) callForumsRefresh];
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

- (UIViewController *)getRootController
{
    return self.navigationController;
}
@end

@implementation AwfulAppDelegateIpad

-(BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [super application:application didFinishLaunchingWithOptions:launchOptions];
    [self.window addSubview:self.splitController.view];
    return YES;
}

- (void) setupSubview
{
    [self.window addSubview:self.splitController.view];
}

- (UIViewController *)getRootController
{
    return self.splitController;
}
@end

UIViewController *getRootController()
{
    AwfulAppDelegate *del = [[UIApplication sharedApplication] delegate];
    return [del getRootController];
}

BOOL isLandscape()
{
    return UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation]);
}


