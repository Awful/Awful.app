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
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (readonly, strong, nonatomic) NSManagedObjectContext *throwawayObjectContext;

- (void)configureAppearance;
-(UIImage*) navigationBarBackgroundImageForMetrics:(UIBarMetrics)metrics;
- (void)saveContext;
- (NSURL *)applicationDocumentsDirectory;
- (void)resetDataStore;
- (void)requestFailed:(NSError *)error;

@end
