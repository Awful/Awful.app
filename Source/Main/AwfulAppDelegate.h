//
//  AwfulAppDelegate.h
//  Awful
//
//  Copyright 2010 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import <UIKit/UIKit.h>

@interface AwfulAppDelegate : NSObject <UIApplicationDelegate>

+ (instancetype)instance;

@property (strong, nonatomic) UIWindow *window;

- (void)logOut;

@end
