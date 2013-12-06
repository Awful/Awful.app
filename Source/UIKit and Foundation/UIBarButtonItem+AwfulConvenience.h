//  UIBarButtonItem+AwfulConvenience.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>

@interface UIBarButtonItem (AwfulConvenience)

/**
 * Returns a UIBarButtonItem of type UIBarButtonSystemItemFlexibleSpace configured with no target.
 */
+ (instancetype)flexibleSpace;

/**
 * Returns a UIBarButtonItem with an empty title that, used as -[UINavigationItem backBarButtonItem], shows just the arrow for a back button.
 */
+ (instancetype)emptyBackBarButtonItem;

@end
