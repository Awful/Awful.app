//  AwfulThemeButton.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import UIKit;

/**
 * An AwfulThemeButton represents a selectable theme.
 */
@interface AwfulThemeButton : UIButton

- (instancetype)initWithThemeColor:(UIColor *)themeColor NS_DESIGNATED_INITIALIZER;

@property (readonly, strong, nonatomic) UIColor *themeColor;

@end
