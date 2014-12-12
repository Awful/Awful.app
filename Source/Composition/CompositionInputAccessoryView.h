//  CompositionInputAccessoryView.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import UIKit;

@interface CompositionInputAccessoryView : UIInputView <UIInputViewAudioFeedback>

- (instancetype)initWithTextView:(UITextView *)textView NS_DESIGNATED_INITIALIZER;

@property (readonly, weak, nonatomic) UITextView *textView;

@property (assign, nonatomic) UIKeyboardAppearance keyboardAppearance;

@end
