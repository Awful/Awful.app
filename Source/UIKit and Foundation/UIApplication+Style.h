//
//  UIDevice+Style.h
//  Awful
//
//  Created by Chris Williams on 10/1/13.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum _UIBackgroundStyle {
	UIBackgroundStyleDefault,
	UIBackgroundStyleTransparent,
	UIBackgroundStyleLightBlur,
	UIBackgroundStyleDarkBlur,
	UIBackgroundStyleDarkTranslucent
} UIBackgroundStyle;

@interface UIApplication (Style)

-(void)setBackgroundMode:(UIBackgroundStyle)style;

@end
