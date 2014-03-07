//  AwfulThemeButton.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>

/**
 * An AwfulThemeButton represents a selectable theme.
 */
@interface AwfulThemeButton : UIButton

- (id)initWithThemeColor:(UIColor *)themeColor;

@property (readonly, strong, nonatomic) UIColor *themeColor;

@end
