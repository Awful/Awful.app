//
//  AwfulLoadingView.h
//  Awful
//
//  Created by Nolan Waite on 2013-06-04.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, AwfulLoadingViewType)
{
    // A spinning progress indicator over a tintColor background.
    AwfulLoadingViewTypeDefault,
    
    // A spinning progress indicator over a sickly green background.
    AwfulLoadingViewTypeGasChamber,
    
    // A spinning progress indicator over a pink background.
    AwfulLoadingViewTypeFYAD,
    
    // A nonstandard ASCII progress indicator in glowing green with monospace type over black.
    AwfulLoadingViewTypeYOSPOS,
    
    // A static monochrome "Welcome to Mac OS"-style screen over an atrocious checked background.
    AwfulLoadingViewTypeMacinyos,
    
    // A rotating hourglass over that ugly Windows 95 teal.
    AwfulLoadingViewTypeWinpos95,
};

// A view that covers its superview with a "loading..." message and progress indicator.
@interface AwfulLoadingView : UIView

// A convenience constructor for creating different loading view configurations.
+ (instancetype)loadingViewWithType:(AwfulLoadingViewType)type;

// A message to display, like "Loading…".
@property (copy, nonatomic) NSString *message;

// Different loading view types use their tint colors in different ways. Some types may ignore all
// attempts to set this property.
@property (nonatomic) UIColor *tintColor;

@end
