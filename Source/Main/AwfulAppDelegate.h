//
//  AwfulAppDelegate.h
//  Awful
//
//  Copyright 2010 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app
//

#import <UIKit/UIKit.h>

@interface AwfulAppDelegate : NSObject <UIApplicationDelegate>

+ (instancetype)instance;

@property (strong, nonatomic) UIWindow *window;

- (void)logOut;

// Sent when the user logs out.
extern NSString * const AwfulUserDidLogOutNotification;

// Handles an awful:// URL.
//
// Returns YES if the awful:// URL made sense, or NO otherwise.
- (BOOL)openAwfulURL:(NSURL *)url;

@end
