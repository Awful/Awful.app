//  SettingsViewController.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIViewController+AwfulTheme.h"
#import "AwfulDataStack.h"

@interface SettingsViewController : AwfulTableViewController

- (id)initWithDataStack:(AwfulDataStack *)dataStack NS_DESIGNATED_INITIALIZER;

@property (readonly, strong, nonatomic) AwfulDataStack *dataStack;

@end
