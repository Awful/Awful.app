//  AwfulLoadingView.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>

// A view that covers its superview with a "loading..." message and progress indicator.
@interface AwfulLoadingView : UIView

// A convenience constructor for creating different loading view configurations.
+ (instancetype)loadingViewForTheme:(AwfulTheme*)theme;

// A message to display, like "Loading…".
@property (copy, nonatomic) NSString *message;

@end
