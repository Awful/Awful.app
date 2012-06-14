//
//  AwfulAppDelegate.m
//  Awful
//
//  Created by Sean Berry on 7/26/10.
//  Copyright Regular Berry Software LLC 2010. All rights reserved.
//

#import "AwfulAppDelegate.h"
#import "AwfulSplitViewController.h"
#import "AwfulSettings.h"
#import "AwfulLoginController.h"
#import "DDLog.h"
#import "DDTTYLogger.h"

@implementation AwfulAppDelegate

@synthesize window = _window;
@synthesize splitController = _splitController;
@synthesize managedObjectContext = __managedObjectContext;
@synthesize managedObjectModel = __managedObjectModel;
@synthesize persistentStoreCoordinator = __persistentStoreCoordinator;
@synthesize throwawayObjectContext = _throwawayObjectContext;

#pragma mark - Application lifecycle

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    [[AwfulSettings settings] registerDefaults];
            
    NSManagedObjectContext *context = [self managedObjectContext];
    if (context == nil) {
        NSLog(@"no managed object context loaded");
    }
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        self.splitController = (AwfulSplitViewController *)self.window.rootViewController;
    } else if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        UITabBarController *tabBar = (UITabBarController *)self.window.rootViewController;
        if(!IsLoggedIn()) {
            tabBar.selectedIndex = 3;
        } else {
            AwfulFirstTab tab = [[AwfulSettings settings] firstTab];
            tabBar.selectedIndex = tab;
        }
    }
    
    // TODO move this out into default.css.
    static CGFloat colors[] = {
        0.294, 0.647, 0.867, 1, // bright light blue; 1px top border, below status bar
        0.153, 0.459, 0.745, 1, // medium blue; top of top half of gradient
        0.098, 0.294, 0.498, 1, // darker medium blue; bottom of top half of gradient
        0.090, 0.251, 0.427, 1, // dark blue; top of bottom half of gradient
        0.078, 0.216, 0.380, 1, // darker blue; bottom of bottom half of gradient
    };
    
    UIImage *portrait = NavigationBarImage(UIBarMetricsDefault, colors);
    [[UINavigationBar appearance] setBackgroundImage:portrait forBarMetrics:UIBarMetricsDefault];
    UIImage *landscape = NavigationBarImage(UIBarMetricsLandscapePhone, colors);
    [[UINavigationBar appearance] setBackgroundImage:landscape
                                       forBarMetrics:UIBarMetricsLandscapePhone];
    
    UIColor *barButton = [UIColor colorWithRed:46.0/255 green:146.0/255 blue:190.0/255 alpha:1];
    [[UIBarButtonItem appearance] setTintColor:barButton];
    
    [self.window makeKeyAndVisible];
    
    return YES;
}

// TODO move NavigationBarImage() out into some new class for dealing with templates.

// Draw a background image for a navigation bar.
//
// metrics - Whether this image is for a default bar or for a phone bar in landscape.
// colors  - Five sets of four RGBA color components. The first set is used as a 1px border at 
//           the top. The next two sets define the top half gradient. The remaining two sets
//           define the bottom half gradient.
//
// Returns a resizable image.
static UIImage *NavigationBarImage(UIBarMetrics metrics, CGFloat colors[])
{
    CGFloat height = metrics == UIBarMetricsDefault ? 42 : 32;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(1, height), YES, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
    CGContextSetFillColorSpace(context, rgb);
    
    // 1px top border, below status bar.
    CGContextSaveGState(context);
    CGContextMoveToPoint(context, 0, 0);
    CGContextAddRect(context, CGRectMake(0, 0, 1, 1));
    CGContextSetFillColor(context, colors); // bright light blue
    CGContextFillPath(context);
    CGContextRestoreGState(context);
    
    // Fake two-tone gradient.
    CGContextSaveGState(context);
    CGFloat locations[] = { 0, 0.5, 0.5, 1.0 };
    CGGradientRef gradient = CGGradientCreateWithColorComponents(rgb, colors + 4, locations, 4);
    // y-values are so the middle of the gradient lines up with bar button items.
    CGContextDrawLinearGradient(context, gradient, CGPointMake(0, 1), CGPointMake(1, height + 1), 0);
    CGGradientRelease(gradient);
    CGContextRestoreGState(context);
    
    CGColorSpaceRelease(rgb);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [image resizableImageWithCapInsets:UIEdgeInsetsMake(height, 0, 0, 0)];
}

#pragma mark - Memory management

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

- (NSManagedObjectContext *)throwawayObjectContext
{
    if (_throwawayObjectContext != nil) {
        return _throwawayObjectContext;
    }
    _throwawayObjectContext = [[NSManagedObjectContext alloc] init];
    NSPersistentStoreCoordinator *store = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    [_throwawayObjectContext setPersistentStoreCoordinator:store];
    [_throwawayObjectContext setUndoManager:nil];
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
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption, 
                             [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption,
                             nil];
    if (![__persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                    configuration:nil
                                                              URL:storeURL
                                                          options:options
                                                            error:&error]) {
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

-(void)resetDataStore
{
    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"AwfulData.sqlite"];
    NSError *err = nil;
    if([storeURL checkResourceIsReachableAndReturnError:&err]) {
        [[NSFileManager defaultManager] removeItemAtURL:storeURL error:&err];
        if(err != nil) {
            NSLog(@"failed to delete data store %@", [err localizedDescription]);
        }
    }

    __persistentStoreCoordinator = nil;
    __managedObjectModel = nil;
    __managedObjectContext = nil;
    [self managedObjectContext];
}

#pragma mark - Application's Documents directory

// Returns the URL to the application's Documents directory.
- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

#pragma mark - Relaying errors

- (void)requestFailed:(NSError *)error
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Network Error"
                                                    message:[error localizedDescription]
                                                   delegate:nil
                                          cancelButtonTitle:@"Drats"
                                          otherButtonTitles:nil];
    [alert show];
}

@end
