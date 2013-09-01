//
//  AwfulExternalBrowser.h
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app
//

#import <Foundation/Foundation.h>

@interface AwfulExternalBrowser : NSObject

+ (NSArray *)installedBrowsers;

@property (readonly, copy, nonatomic) NSString *title;

- (BOOL)isInstalled;

- (void)openURL:(NSURL *)url;

- (BOOL)canOpenURL:(NSURL *)url;

@end
