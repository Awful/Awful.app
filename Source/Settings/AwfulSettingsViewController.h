//  AwfulSettingsViewController.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIViewController+AwfulTheme.h"

@interface AwfulSettingsViewController : AwfulTableViewController

// Designated initializer.
- (id)initWithManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;

@end
