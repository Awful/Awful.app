//  SettingsViewController.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulViewController.h"
@import CoreData;

@interface SettingsViewController : AwfulTableViewController

- (instancetype)initWithManagedObjectContext:(NSManagedObjectContext *)managedObjectContext NS_DESIGNATED_INITIALIZER;

@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;

@end
