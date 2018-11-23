//  WKWebView+RegisterScheme.m
//
//  Copyright 2018 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "WKWebView+RegisterScheme.h"

@implementation WKWebView (AwfulWKWebViewHack)

+ (void)awful_registerCustomURLScheme:(NSString *)scheme {
    // Written in Objective-C so we can catch exceptions.
    @try {
        Class contextClass = NSClassFromString([@[@"WK", @"Browsing", @"Context", @"Controller"] componentsJoinedByString:@""]);
        SEL registerSelector = NSSelectorFromString([@[@"register", @"Scheme", @"For", @"Custom", @"Protocol:"] componentsJoinedByString:@""]);
        if ([contextClass respondsToSelector:registerSelector]) {
            
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            
            [contextClass performSelector:registerSelector withObject:scheme];
            
            #pragma clang diagnostic pop
        }
    } @catch (id _) {
        // nop
    }
}

@end
