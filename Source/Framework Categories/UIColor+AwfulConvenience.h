//  UIColor+AwfulConvenience.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import UIKit;

@interface UIColor (AwfulConvenience)

// Returns a UIColor from the specified hex code
+ (instancetype)awful_colorWithHexCode:(NSString*)hexCode;

/// Returns an HTML hex color, or nil if the color isn't RGB-compatible.
@property (readonly, nonatomic) NSString *awful_hexCode;

@end
