//  SmilieButton.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import UIKit;

IB_DESIGNABLE
@interface SmilieButton : UIButton

@property (strong, nonatomic) IBInspectable UIColor *normalBackgroundColor;
@property (strong, nonatomic) IBInspectable UIColor *selectedBackgroundColor;

@end

// This is its own class only because you can't specify which bundle has the image you set in Interface Builder, so using next_image works fine in IB but fails when actually running.
// As a handy coincidence, this way also loads the image as a template image when rendering in IB, so it's tinted properly.
@interface SmilieNextKeyboardButton : SmilieButton

@end
