//  AwfulNavigationController.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import UIKit;
#import "AwfulNavigationBar.h"
#import "AwfulToolbar.h"
#import "AwfulUnpoppingViewHandler.h"

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

/**
 * Returns the handler responsible for managing unpopping views
 */
@property (readonly, strong, nonatomic) AwfulUnpoppingViewHandler *unpopHandler;

@end
