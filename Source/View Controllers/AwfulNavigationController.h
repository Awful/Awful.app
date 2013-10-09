//  AwfulNavigationController.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>
#import "AwfulNavigationBar.h"
#import "AwfulToolbar.h"

/**
 * An AwfulNavigationController calls -themeDidChange after its view loads.
 */
@interface AwfulNavigationController : UINavigationController

/**
 * Returns a navigation controller's navigation bar.
 */
@property (readonly, strong, nonatomic) AwfulNavigationBar *navigationBar;

/**
 * Returns a navigation controller's toolbar.
 */
@property (readonly, strong, nonatomic) AwfulToolbar *toolbar;

@end
