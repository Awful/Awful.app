//
//  AwfulAppDelegate.m
//  Awful
//
//  Created by Sean Berry on 7/26/10.
//  Copyright Regular Berry Software LLC 2010. All rights reserved.
//

#import "AwfulAppDelegate.h"
#import "FlurryAPI.h"
#import "Appirater.h"
#import "AwfulSplitViewController.h"
#import "AwfulNetworkEngine.h"
#import "AwfulTabBarController.h"

@implementation AwfulAppDelegate

@synthesize window = _window;
@synthesize splitController = _splitController;
@synthesize awfulNetworkEngine = _awfulNetworkEngine;
@synthesize managedObjectContext = __managedObjectContext;
@synthesize managedObjectModel = __managedObjectModel;
@synthesize persistentStoreCoordinator = __persistentStoreCoordinator;

#pragma mark -
#pragma mark Application lifecycle

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {    
        
    // Override point for customization after application launch.
    
    self.awfulNetworkEngine = [[AwfulNetworkEngine alloc] initWithHostName:@"forums.somethingawful.com" customHeaderFields:nil];
    
    NSManagedObjectContext *context = [self managedObjectContext];
    if(context == nil) {
        NSLog(@"no managed object context loaded");
    }
    
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        self.splitController = (AwfulSplitViewController *)self.window.rootViewController;
    }
    
    UIImage *img = [[UIImage imageNamed:@"navbargradient"] resizableImageWithCapInsets:UIEdgeInsetsMake(42, 0, 0, 0)];
    [[UINavigationBar appearance] setBackgroundImage:img forBarMetrics:UIBarMetricsDefault];
    [[UIBarButtonItem appearance] setTintColor:[UIColor colorWithRed:46.0/255 green:146.0/255 blue:190.0/255 alpha:1.0]];
    
    [self.window makeKeyAndVisible];
    
    //[FlurryAPI startSession:@"EU3TLVQM9U8T8QKNI9ID"];
    
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
    /*AwfulNavigator *nav = getNavigator();
    if ([nav isKindOfClass:[AwfulNavigatorIpad class]])
        [((AwfulNavigatorIpad *) nav) callForumsRefresh];*/
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
    return self.window.rootViewController;
}

-(void)initializeData
{
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"SleepingCat" inManagedObjectContext:self.managedObjectContext];
    [request setEntity:entity];
    
    NSError *error = nil;
    NSMutableArray *results = [[self.managedObjectContext executeFetchRequest:request error:&error] mutableCopy];
    if(results == nil) {
        NSLog(@"couldn't load any forums");
        return;
    }
    if([results count] == 0) {
        // insert mine
        /*NSDictionary *dict = [NSDictionary dictionaryWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"NoodleVids" withExtension:@"plist"]];
        NSArray *vids = [dict objectForKey:@"noodles"];
        for(NSString *vid_name in vids) {
            //SleepingCat *cat = (SleepingCat *)[NSEntityDescription insertNewObjectForEntityForName:@"SleepingCat" inManagedObjectContext:self.managedObjectContext];
            
            NSError *save_error = nil;
            if(![ApplicationDelegate.managedObjectContext save:&save_error]) {
                // fail?
            }
            
        }*/
    }
}

- (void)saveContext
{
    NSError *error = nil;
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    if (managedObjectContext != nil) {
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        } 
    }
}

#pragma mark - Core Data stack

// Returns the managed object context for the application.
// If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
- (NSManagedObjectContext *)managedObjectContext
{
    if (__managedObjectContext != nil) {
        return __managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        __managedObjectContext = [[NSManagedObjectContext alloc] init];
        [__managedObjectContext setPersistentStoreCoordinator:coordinator];
        [__managedObjectContext setUndoManager:nil];
    }
    return __managedObjectContext;
}

// Returns the managed object model for the application.
// If the model doesn't already exist, it is created f.rom the application's model.
- (NSManagedObjectModel *)managedObjectModel
{
    if (__managedObjectModel != nil) {
        return __managedObjectModel;
    }
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"Model" withExtension:@"momd"];
    __managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return __managedObjectModel;
}

// Returns the persistent store coordinator for the application.
// If the coordinator doesn't already exist, it is created and the application's store added to it.
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (__persistentStoreCoordinator != nil) {
        return __persistentStoreCoordinator;
    }
    
    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"AwfulData.sqlite"];
    
    NSError *error = nil;
    __persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    if (![__persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) {
        /*
         Replace this implementation with code to handle the error appropriately.
         
         abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
         
         Typical reasons for an error here include:
         * The persistent store is not accessible;
         * The schema for the persistent store is incompatible with current managed object model.
         Check the error message to determine what the actual problem was.
         
         
         If the persistent store is not accessible, there is typically something wrong with the file path. Often, a file URL is pointing into the application's resources directory instead of a writeable directory.
         
         If you encounter schema incompatibility errors during development, you can reduce their frequency by:
         * Simply deleting the existing store:
         [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil]
         
         * Performing automatic lightweight migration by passing the following dictionary as the options parameter: 
         [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption, [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption, nil];
         
         Lightweight migration will only work for a limited set of schema changes; consult "Core Data Model Versioning and Data Migration Programming Guide" for details.
         
         */
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }    
    
    return __persistentStoreCoordinator;
}

#pragma mark - Application's Documents directory

// Returns the URL to the application's Documents directory.
- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

@end



BOOL isLandscape()
{
    return UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation]);
}


