//  KeyboardBar.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import UIKit;

@protocol KeyboardBarDelegate;

@interface KeyboardBar : UIInputView <UIInputViewAudioFeedback>

@property (weak, nonatomic) id <KeyboardBarDelegate> delegate;

@property (weak, nonatomic) UITextView *textView;

@property (assign, nonatomic) UIKeyboardAppearance keyboardAppearance;

@end

@protocol KeyboardBarDelegate <NSObject>

- (void)toggleSmilieKeyboardForKeyboardBar:(KeyboardBar *)keyboardBar;

@end
