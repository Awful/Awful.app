//  KeyboardBar.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import UIKit;
@protocol KeyboardBarDelegate;

@interface KeyboardBar : UIInputView <UIInputViewAudioFeedback>

- (instancetype)initWithFrame:(CGRect)frame textView:(UITextView *)textView NS_DESIGNATED_INITIALIZER;

@property (readonly, weak, nonatomic) UITextView *textView;

@property (weak, nonatomic) id <KeyboardBarDelegate> delegate;

@property (assign, nonatomic) UIKeyboardAppearance keyboardAppearance;

@end

@protocol KeyboardBarDelegate <NSObject>

- (void)toggleSmilieKeyboardForKeyboardBar:(KeyboardBar *)keyboardBar;

@end
