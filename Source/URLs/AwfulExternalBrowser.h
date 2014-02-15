//  AwfulExternalBrowser.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <Foundation/Foundation.h>

#import "AwfulURLActivity.h"

@interface AwfulExternalBrowser : AwfulURLActivity

+ (NSArray *)availableBrowserActivities;

@end