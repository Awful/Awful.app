//  UIDevice+OperatingSystemVersion.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>

@interface UIDevice (OperatingSystemVersion)

// Returns YES if this device is running any version of iOS 5.
- (BOOL)awful_iOS5;

// Returns YES if this device is running iOS 6.0 or a later version.
- (BOOL)awful_iOS6OrLater;

@end
