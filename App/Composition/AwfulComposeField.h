//  AwfulComposeField.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import UIKit;

/**
 * An AwfulComposeField is a labelled text field suitable for perching atop a compose text view.
 */
@interface AwfulComposeField : UIView

@property (readonly, strong, nonatomic) UILabel *label;

@property (readonly, strong, nonatomic) UITextField *textField;

@end
