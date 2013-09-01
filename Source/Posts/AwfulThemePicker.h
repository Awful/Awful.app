//  AwfulThemePicker.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>

// Like a UISegmentedControl but with more customizable segments.
@interface AwfulThemePicker : UIControl

// UISegmentedControlNoSegment is a valid selected index.
@property (nonatomic) NSInteger selectedThemeIndex;

- (void)insertThemeWithColor:(UIColor *)color atIndex:(NSInteger)index;

@end
