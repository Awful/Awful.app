//  AwfulKeyboardBar.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>

@interface AwfulKeyboardBar : UIView <UIInputViewAudioFeedback>

@property (copy, nonatomic) NSArray *characters;

@property (weak, nonatomic) id <UIKeyInput> keyInputView;

@end
