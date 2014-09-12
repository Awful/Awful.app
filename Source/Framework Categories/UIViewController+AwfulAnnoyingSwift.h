//  UIViewController+AwfulAnnoyingSwift.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import UIKit;

@interface UIViewController (AwfulAnnoyingSwift)

/**
 * Setting the `restorationClass` to `nil` from Swift causes a crash on a device when built with the Release configuration (iOS 8.0 GM). Call this method instead to avoid the crash. rdar://18315383
 */
- (void)awful_clearRestorationClass;

@end
