//  UIWebView+AwfulConvenience.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>

@interface UIWebView (AwfulConvenience)

/**
 * Returns the result of running a script specified as a format string.
 */
- (NSString *)awful_evalJavaScript:(NSString *)script, ... NS_FORMAT_FUNCTION(1, 2);

@end
