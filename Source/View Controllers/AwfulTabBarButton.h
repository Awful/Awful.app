//  AwfulTabBarButton.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>

/**
 * An AwfulTabBarButton draws an icon.
 */
@interface AwfulTabBarButton : UIButton

/**
 * Sets the button's image in the UIControlStateNormal and UIControlStateSelected states, using `image` as a template and the button's `tintColor` for the selected color.
 *
 * @param image An image which is used as a mask.
 */
- (void)setImage:(UIImage *)image;

@end
