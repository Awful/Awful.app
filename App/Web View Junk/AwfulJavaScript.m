//  AwfulJavaScript.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulJavaScript.h"
#import <WebViewJavascriptBridge/WebViewJavascriptBridge.h>

NSString * LoadJavaScriptResources(NSArray *filenames, NSError * __autoreleasing *error)
{
    NSMutableArray *scripts = [NSMutableArray new];
    for (NSString *filename in filenames) {
        NSURL *URL = [[NSBundle mainBundle] URLForResource:filename withExtension:nil];
        // Loading CocoaPods framework resources can be tricky. I'm not sure why this file doesn't end up in the Resources folder of the framework, but let's assume it will someday.
        if ([filename isEqualToString:@"WebViewJavascriptBridge.js.txt"]) {
            NSBundle *bundle = [NSBundle bundleForClass:[WebViewJavascriptBridge class]];
            URL = [bundle URLForResource:filename withExtension:nil] ?: [bundle.bundleURL URLByAppendingPathComponent:filename];
        }
        NSString *script = [NSString stringWithContentsOfURL:URL encoding:NSUTF8StringEncoding error:error];
        if (!script) {
            if (error && ![*error userInfo][NSURLErrorKey]) {
                NSMutableDictionary *userInfo = [[*error userInfo] mutableCopy];
                userInfo[NSURLErrorKey] = URL ?: [NSURL URLWithString:filename];
                *error = [NSError errorWithDomain:[*error domain] code:[*error code] userInfo:userInfo];
            }
            return nil;
        }
        [scripts addObject:script];
    }
    return [scripts componentsJoinedByString:@"\n\n"];
}
