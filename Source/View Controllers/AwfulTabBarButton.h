//  AwfulTabBarButton.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>

/**
 * An AwfulTabBarButton draws an icon.
 */
@interface AwfulTabBarButton : UIButton

/**
 * An image to use as a template for button's image in the UIControlStateNormal (tinted grey) and UIControlStateSelected (tinted tintColor) states.
 */
@property (strong, nonatomic) UIImage *image;

@end
