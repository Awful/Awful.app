//  AwfulThemePicker.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>

/**
 * An AwfulThemePicker acts as a segmented control for themes.
 */
@interface AwfulThemePicker : UIControl

/**
 * The currently-selected theme's index, or UISegmentedControlNoSegment is no theme is selected.
 */
@property (assign, nonatomic) NSInteger selectedThemeIndex;

/**
 * Insert a new theme.
 *
 * @param color A color describing the theme. Set its accessibilityLabel to a descriptive name.
 * @param index Where to insert the theme.
 */
- (void)insertThemeWithColor:(UIColor *)color atIndex:(NSInteger)index;

/**
 * If, during constraint-based layout, the picker would expand beyond this width, instead its height increases. Default is 0, indicating a single line of theme buttons.
 */
@property (assign, nonatomic) CGFloat preferredMaxLayoutWidth;

@end
