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

+ (instancetype)awful_nativeFeelingWebView
{
    UIWebView *webView = [self new];
    webView.scalesPageToFit = YES;
    webView.scrollView.decelerationRate = UIScrollViewDecelerationRateNormal;
    webView.dataDetectorTypes = UIDataDetectorTypeNone;
    webView.opaque = NO;
    return webView;
}

- (CGRect)awful_rectForElementBoundingRect:(NSString *)rectString
{
    UIScrollView *scrollView = self.scrollView;
    UIEdgeInsets insets = scrollView.contentInset;
    return CGRectOffset(CGRectFromString(rectString), insets.left, insets.top);
}

@end
