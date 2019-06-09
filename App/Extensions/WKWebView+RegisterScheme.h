//  WKWebView+RegisterScheme.h
//
//  Copyright 2018 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKWebView (AwfulRegisterScheme)

/**
 Tells `WKWebView` instances to look for a registered `URLProtocol` subclass when loading URLs with a given scheme.
 
 `WKURLSchemeHandler` is iOS 11+. When our deployment target allows, we should definitely move to that and delete this category.
 */
+ (void)awful_registerCustomURLScheme:(NSString *)scheme NS_SWIFT_NAME(registerCustomURLScheme(_:));

@end

NS_ASSUME_NONNULL_END
