//  UIApplication+Style.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>

typedef enum _UIBackgroundStyle {
	UIBackgroundStyleDefault,
	UIBackgroundStyleTransparent,
	UIBackgroundStyleLightBlur,
	UIBackgroundStyleDarkBlur,
	UIBackgroundStyleDarkTranslucent
} UIBackgroundStyle;

@interface UIApplication (Style)

- (void)setBackgroundMode:(UIBackgroundStyle)style;

@end
