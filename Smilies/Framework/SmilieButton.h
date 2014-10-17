//  SmilieButton.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import UIKit;

/**
 A SmilieButton can change its background color and its tint color depending on its state.
 */
IB_DESIGNABLE
@interface SmilieButton : UIButton

/**
 * The tint color to use when the button is highlighted or selected.
 */
@property (strong, nonatomic) IBInspectable UIColor *selectedTintColor;

@property (strong, nonatomic) IBInspectable UIColor *normalBackgroundColor;

/**
 * The background color to use when the button is highlighted or selected.
 */
@property (strong, nonatomic) IBInspectable UIColor *selectedBackgroundColor;

@end

/*
 These are their own classes because:
   * You can't specify which bundle has the image you set in Interface Builder, so using Smilies.framework image assets from other bundles works in IB but fails at runtime.
   * This way properly loads the image as a template image when rendering in IB, so it's tinted properly.
 */
@interface SmilieDeleteButton : SmilieButton @end
@interface SmilieFavoriteButton : SmilieButton @end
@interface SmilieGridButton : SmilieButton @end
@interface SmilieNextKeyboardButton : SmilieButton @end
@interface SmilieRecentButton : SmilieButton @end
