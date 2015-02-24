//  main.m
//
//  Copyright 2010 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import UIKit;
#import "AwfulAppDelegate.h"

int main(int argc, char *argv[]) {
    @autoreleasepool {
        NSString *appDelegateClassName = NSClassFromString(@"XCTestCase") ? @"TestAppDelegate" : NSStringFromClass([AwfulAppDelegate class]);
        return UIApplicationMain(argc, argv, nil, appDelegateClassName);
    }
}
