//
//  UIDevice+OperatingSystemVersion.h
//  Awful
//
//  Created by Nolan Waite on 2013-05-07.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIDevice (OperatingSystemVersion)

// Returns YES if this device is running any version of iOS 5.
- (BOOL)awful_iOS5;

// Returns YES if this device is running iOS 6.0 or a later version.
- (BOOL)awful_iOS6OrLater;

@end
