//  UIWebView+AwfulConvenience.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIWebView+AwfulConvenience.h"

@implementation UIWebView (AwfulConvenience)

- (NSString *)awful_evalJavaScript:(NSString *)script, ...
{
    va_list args;
    va_start(args, script);
    NSString *formatted = [[NSString alloc] initWithFormat:script arguments:args];
    va_end(args);
    return [self stringByEvaluatingJavaScriptFromString:formatted];
}

@end
