//  AwfulThemingViewController.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <Foundation/Foundation.h>

@protocol AwfulThemingViewController <NSObject>

// Feel free to call super if the superclass implements this protocol.
// The topmost class in a hierarchy that implements this protocol should send -retheme in
// -viewDidLoad or similar; subclasses should not, so work is not repeated.
- (void)retheme;

@end
