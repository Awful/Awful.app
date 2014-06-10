//  UIColor+AwfulConvenience.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIColor+AwfulConvenience.h"

@implementation UIColor (AwfulConvenience)

+ (instancetype)awful_colorWithHexCode:(NSString *)hexCode
{
	if (hexCode == nil) return nil;
	
    NSMutableString *hexString = [NSMutableString stringWithString:hexCode];
    [hexString replaceOccurrencesOfString:@"#" withString:@"" options:0 range:NSMakeRange(0, hexString.length)];
    CFStringTrimWhitespace((__bridge CFMutableStringRef)hexString);
    if (!(hexString.length == 6 || hexString.length == 8)) return nil;
    
    unsigned int red, green, blue, alpha = 255;
    [[NSScanner scannerWithString:[hexString substringWithRange:NSMakeRange(0, 2)]] scanHexInt:&red];
    [[NSScanner scannerWithString:[hexString substringWithRange:NSMakeRange(2, 2)]] scanHexInt:&green];
    [[NSScanner scannerWithString:[hexString substringWithRange:NSMakeRange(4, 2)]] scanHexInt:&blue];
    if (hexString.length > 6) {
        [[NSScanner scannerWithString:[hexString substringWithRange:NSMakeRange(6, 2)]] scanHexInt:&alpha];
    }
    return [UIColor colorWithRed:(red / 255.) green:(green / 255.) blue:(blue / 255.) alpha:(alpha / 255.)];
}

@end
