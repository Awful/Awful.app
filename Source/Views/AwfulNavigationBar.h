//  AwfulNavigationBar.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>

// A navigation bar we can target for UIAppearance, it also pop to its navigation controller's root
// when the back button is long-tapped.
@interface AwfulNavigationBar : UINavigationBar

// If non-nil, this block gets called when long-tapping the left button.
// If nil, the default pop to root action occurs.
@property (nonatomic, copy) void (^leftButtonLongTapAction)(void);

@end
