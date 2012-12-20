//
//  AwfulExternalBrowser.h
//  Awful
//
//  Created by Nolan Waite on 2012-12-19.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AwfulExternalBrowser : NSObject

+ (NSArray *)installedBrowsers;

@property (readonly, copy, nonatomic) NSString *title;

- (BOOL)isInstalled;

- (void)openURL:(NSURL *)url;

- (BOOL)canOpenURL:(NSURL *)url;

@end
