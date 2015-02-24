//  AwfulNavigationController.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import UIKit;
#import "AwfulNavigationBar.h"
#import "AwfulToolbar.h"

/**
 * An AwfulNavigationController adds theming support; hosts an AwfulNavigationBar and AwfulToolbar; shows and hides the toolbar depending on whether the view controller has toolbar items; and, on iPhone, allows swiping from the *right* screen edge to unpop a view controller.
 */
@interface AwfulNavigationController : UINavigationController

/**
 * Redeclared to return an AwfulNavigationBar.
 */
@property (readonly, strong, nonatomic) AwfulNavigationBar *navigationBar;

/**
 * Redeclared to return an AwfulToolbar.
 */
@property (readonly, strong, nonatomic) AwfulToolbar *toolbar;

@end
